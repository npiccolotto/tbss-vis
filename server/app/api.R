library("pryr")
library("zoo")
library("hash")
library("moments")
library("tsBSS")
library("cluster")
library("digest")
library("tictoc")
library("reshape2")
library("lhs")
library("MASS")
library("philentropy")
# Tidyverse
library("purrr")
library("tibble")
library("lubridate")
library("dplyr")

setwd('/app/')




#### DATA INIT
set.seed(321)
dataset_name <- Sys.getenv('TSBSS_DATASET')
if (dataset_name == '') {
  print("[WARNING]: TSBSS_DATASET unset, using default dataset")
  dataset_name <- 'synth'
}
dataset_path <- paste('data/', dataset_name, '.csv', sep='')
dataset_original <- read.csv(dataset_path)
dates.char <- dataset_original$date
dataset <- as.matrix(dataset_original[, -1])
dataset.sd <- unlist(unname(apply(dataset, 2, 'sd')))
dataset.SD <- diag(dataset.sd)

rownames(dataset) <- dates.char
print('== DATASET == ')
print(paste('path: ', dataset_path))
print(paste('nrow: ', nrow(dataset)))
print(paste('ncol: ', ncol(dataset)))
print(colnames(dataset))

# SOBI works on zoo data, but zoo doesn't interplay nice with other functions
# so we keep it zoo-ed and un-zoo-ed.
dataset.zoo <- zoo::zoo(dataset)
attr(dataset.zoo, "index") <- as.Date(dates.char)

norm_power <- function(v) {
  return(
    (v - mean(v)) /
      sqrt( sum( (v - mean(v))^2 ))
  )
}

supported_sort_metrics <- c('skewness', 'kurtosis', 'periodicity') #
supported_sort_metrics_fns <- hash::hash()
supported_sort_metrics_fns[['skewness']] <-
  function(ts) {
    return(abs(moments::moment(ts, order = 3)))
  }
supported_sort_metrics_fns[['kurtosis']] <-
  function(ts) {
    return(moments::moment(ts, order = 4))
  }
supported_sort_metrics_fns[['periodicity']] <-
  function(ts) {
    return(max(norm_power(spectrum(ts, plot=F)$spec)))
  }

figure_sort_metric_out_from_sobi_result <-
  function(id, metric, sobi) {
    if (metric == 'volatility') {
      cpy <- sobi$volTS
      names(cpy) <-
        unlist(lapply(colnames(sobi$S), function(n) {
          return(paste(id, n, sep = '#'))
        }))
      return(cpy)
    }
    stop('what are you doing')
  }

is.a <- function(x) {
  return(!is.na(x))
}
assign_running_number <- function(x) {
  x %>%
    diff() %>%
    c(0, .) %>%
    replace(abs(.) > 0, 1) %>%
    cumsum()
}

options(digits.secs=3)
dates.parsed <- lubridate::as_datetime(dates.char)
dates.relative <- data.frame(
  "date_char" = dates.char,
  "year" = lubridate::year(dates.parsed),
  "month" = lubridate::month(dates.parsed),
  "week" = lubridate::week(dates.parsed),
  "day" = lubridate::day(dates.parsed),
  "hour" = lubridate::hour(dates.parsed),
  "minute" = lubridate::minute(dates.parsed),
  "second" = round(lubridate::second(dates.parsed)),
  "millisecond" = lubridate::second(dates.parsed) * 1000
)

dates.relative <- dates.relative %>% dplyr::mutate_if(is.numeric, assign_running_number)

#### UTILS

# Adapted PAM from doi:10.1016/j.eswa.2008.01.039
cop_pam <-
  function(data,
           cantLink,
           k,
           diss = F,
           compute_stats = F) {

    fast_dist <- function(x, y) {
      return(1 - abs(cor(x,y)))
    }

    compute_cluster_representative_and_diameter_and_cardinality <-
      function(pred) {
        R <- matrix(0, nrow = k, ncol = 3)
        for (i in 1:k) {
          elements <- which(pred %in% c(i))
          n <- length(elements)
          if (n == 0) {
            next

          }
          if (n == 1) {
            R[i, ] <- c(elements[1], 0, n)
            next

          }
          dists <-
            outer(elements, elements, Vectorize(function(x, y) {
              return(fast_dist(data[x,], data[y,]))
            }))
          R[i, ] <-
            c(elements[which.min(colSums(dists))], max(dists), n)
        }
        return(R)
      }

    compute_cluster_representative_dist <- function(pred, clusinfo) {
      return(unlist(map(1:length(pred), function(i) {
        element <- data[i,]
        cluster <- pred[i]
        j <- clusinfo[cluster, 1]
        representative <- data[j,]
        return(fast_dist(element, representative))
      })))
    }

    compute_cluster_separation <- function(pred) {
      MD <- matrix(NA, nrow = k, ncol = k)
      cluster_comparison_pairs <- t(combn(1:k, 2))
      for (pair_idx in 1:nrow(cluster_comparison_pairs)) {
        c1 <- cluster_comparison_pairs[pair_idx, 1]
        c2 <- cluster_comparison_pairs[pair_idx, 2]

        elements_c1 <- which(pred %in% c(c1))
        elements_c2 <- which(pred %in% c(c2))
        if (length(elements_c1) > 0 && length(elements_c2) > 0) {
          dists <- outer(elements_c1, elements_c2, Vectorize(function(x, y) {
            return(fast_dist(data[x,], data[y,]))
          }))
          MD[c1, c2] <- min(dists)
          MD[c2, c1] <- min(dists)
        } else {
          MD[c1, c2] <- NA
          MD[c1, c2] <- NA
        }
      }
      return(apply(MD, 2, function(x) {
        if (all(is.na(x))) {
          return(NA) # otherwise min returns Inf and that screws mean()
        }
        return(min(x, na.rm = T))
      }))
    }

    collect_and_return <- function(cluster_labels) {
      if (compute_stats) {
        representatives_and_more <-
          compute_cluster_representative_and_diameter_and_cardinality(cluster_labels)
        representatives_and_more <- cbind(representatives_and_more, compute_cluster_separation(cluster_labels))
        distances_to_representative <-
          compute_cluster_representative_dist(cluster_labels, representatives_and_more)
        clusinfo <- representatives_and_more
        return(
          list(
            labels = cluster_labels,
            distances_to_representative = distances_to_representative,
            clusinfo = clusinfo
          )
        )
      } else {
        return(cluster_labels)
      }
    }

    is_compatible_with_all <- function(clw, i, candidates) {
      if (all(is.na(clw[[i]]))) {
        return(T)
      }
      return(length(intersect(candidates, clw[[i]])) == 0)
    }

    can_put_element_in_cluster <- function(label, clw, i, j) {
      if (all(is.na(clw[[i]]))) {
        return(T)
      }
      for (u in clw[[i]]) {
        if (label[u] == j) {
          return(F)
        }
      }
      return(T)
    }

    if (!diss && k > nrow(data)) {
      return(0)
    }

    # building cannot link lists
    # this is more efficient than reducing from a nxn binary constraint matrix
    nc <- nrow(cantLink)
    n <- nrow(data)
    cannot_link_list <- list()
    for (i in 1:n) {
      cannot_link_list[[i]] <- NA
    }

    for (i in 1:nc) {
      if (i > nc)
        break

      u <- cantLink[i, 1]
      v <- cantLink[i, 2]
      if (any(is.na(cannot_link_list[[u]]))) {
        cannot_link_list[[u]] <- c(v)
      } else {
        cannot_link_list[[u]] <- c(cannot_link_list[[u]], v)
      }
      if (any(is.na(cannot_link_list[[v]]))) {
        cannot_link_list[[v]] <- c(u)
      } else {
        cannot_link_list[[v]] <- c(cannot_link_list[[v]], u)
      }
    }

    # build distance matrix
    D <- as.matrix(data)
    if (!diss) {
      data <- as.matrix(data)
      d <- ncol(data)

      D <- matrix(0, ncol=n, nrow=n)
      triangle <- combn(1:n,2)
      for (v in 1:ncol(triangle)) {
        i <- triangle[1,v]
        j <- triangle[2,v]
        d <- 0
        if (i != j) {
          d <- fast_dist(data[i,], data[j,])
        }
        D[i,j] <- d
        D[j,i] <- d
      }
    }

    does_clustering_violate_constraints <- function(assignments, cll) {
      violations <- rep(T, length(assignments))
      for (i in 1:length(assignments)) {
        assigned_medoid <- assignments[i]
        violations[i] <- !can_put_element_in_cluster(assignments, cll, i, assigned_medoid)
      }
      return(violations)
    }

    find_new_medoid <- function(assignments, medoid_idx) {
      n <- length(assignments)
      elements_in_cluster <- (1:n)[assignments %in% c(medoid_idx)]
      new_medoid_idx <- which.min(unlist(lapply(elements_in_cluster, function(e) {
        return(sum(D[e,elements_in_cluster]))
      })))
      return(elements_in_cluster[new_medoid_idx])
    }

    assign_to_nearest_medoid <- function(object_idxs, medoid_idxs, cll) {
      n <- length(object_idxs)
      assignments <- rep(0, n)
      medoids <- (1:n)[medoid_idxs]
      for (i in 1:n) {
        o <- object_idxs[i]
        available_medoids <- c()
        for (m in medoid_idxs) {
          if (can_put_element_in_cluster(assignments, cll, i, m)) {
            available_medoids <- c(available_medoids, m)
          }
        }
        if (length(available_medoids) == 0){
          stop('no available medoid')
        }

        nearest_idx <- which.min(D[o, available_medoids])
        assignments[i] <- available_medoids[nearest_idx]
      }
      return(assignments)
    }

    calc_cost <- function(assignments, M) {
      object_idxs <- 1:length(assignments)
      C <- cbind(object_idxs, assignments)
      return(sum(apply(C, 1, function(r) {
        o <- r[1]
        m <- M[r[2]]
        return(D[o,m])
      })))
    }

    # initial medoids are from unconstrained PAM - in our case distances suggest the correct partitioning anyhow
    initial <- cluster::pam(D, k, diss=T, pamonce = 0, trace.lev = 0)
    A <- as.integer(initial$clustering)
    M <- unlist(lapply(initial$medoids, function(a) {
      return(match(a, initial$medoids))
    }))

    # while the constraints are violated we reassign to next best medoid
    constraint_violations <- does_clustering_violate_constraints(A, cannot_link_list)
    C <- calc_cost(A, M)
    C.star <- 0
    while(any(constraint_violations) || abs(C.star - C) > 1e-4) {
      C <- C.star
      M.star <- M
      for (j in 1:k) {
        M.star[j] <- find_new_medoid(A, j)
      }

      A.star <- assign_to_nearest_medoid(1:n, M.star, cannot_link_list)
      A.star <- unlist(lapply(A.star, function(a) {
        return(match(a, M.star))
      }))

      A <- A.star
      M <- M.star
      C.star <- calc_cost(A.star, M.star)
      constraint_violations <- does_clustering_violate_constraints(A, cannot_link_list)
    }

    return(collect_and_return(A))
  }



# Adapted COP K-means from conclust
# https://cran.r-project.org/web/packages/conclust/index.html
# Changes:
# - Don't always iterate `maxIter` times, but stop once clusters don't change
# - More idiomatic R (vectorized operations and such)
# - Remove ML constraints because I don't need them

cop_kmeans <-
  function(data,
           cannot_link,
           k,
           maxiter = 100,
           compute_stats = F) {
    # TODO can we compute distances once? probs not because we compare to always-changing centroids
    # only stats computation at the end can benefit from distance matrix
    # using philentropy is slower than this implementation
    fast_dist <- function(x, y) {
      return(1 - abs(cor(x,y)))
      # return(sqrt(sum((x - y) ^ 2)))
    }

    compute_cluster_representative_and_diameter_and_cardinality <-
      function(pred) {
        R <- matrix(0, nrow = k, ncol = 3)
        for (i in 1:k) {
          elements <- which(pred %in% c(i))
          n <- length(elements)
          if (n == 0) {
            next

          }
          if (n == 1) {
            R[i, ] <- c(elements[1], 0, n)
            next

          }
          dists <-
            outer(elements, elements, Vectorize(function(x, y) {
              return(fast_dist(data[x,], data[y,]))
            }))
          R[i, ] <-
            c(elements[which.min(colSums(dists))], max(dists), n)
        }
        return(R)
      }

    compute_cluster_representative_dist <- function(pred, clusinfo) {
      return(unlist(map(1:length(pred), function(i) {
        element <- data[i,]
        cluster <- pred[i]
        j <- clusinfo[cluster, 1]
        representative <- data[j,]
        return(fast_dist(element, representative))
      })))
    }

    compute_cluster_separation <- function(pred) {
      MD <- matrix(NA, nrow = k, ncol = k)
      cluster_comparison_pairs <- t(combn(1:k, 2))
      for (pair_idx in 1:nrow(cluster_comparison_pairs)) {
        c1 <- cluster_comparison_pairs[pair_idx, 1]
        c2 <- cluster_comparison_pairs[pair_idx, 2]

        elements_c1 <- which(pred %in% c(c1))
        elements_c2 <- which(pred %in% c(c2))
        if (length(elements_c1) > 0 && length(elements_c2) > 0) {
          dists <- outer(elements_c1, elements_c2, Vectorize(function(x, y) {
            return(fast_dist(data[x,], data[y,]))
          }))
          MD[c1, c2] <- min(dists)
          MD[c2, c1] <- min(dists)
        } else {
          MD[c1, c2] <- NA
          MD[c1, c2] <- NA
        }
      }
      return(apply(MD, 2, function(x) {
        if (all(is.na(x))) {
          return(NA) # otherwise min returns Inf and that screws mean()
        }
        return(min(x, na.rm = T))
      }))
    }

    can_put_element_in_cluster <- function(label, clw, i, j) {
      if (all(is.na(clw[[i]]))) {
        return(T)
      }
      for (u in clw[[i]]) {
        if (label[u] == j) {
          return(F)
        }
      }
      return(T)
    }

    data <- as.matrix(data)
    n <- nrow(data)
    d <- ncol(data)
    nc <- nrow(cannot_link)

    if (k > n) {
      return(0)
    }

    cannot_link_list <- list()
    for (i in 1:n) {
      cannot_link_list[[i]] <- NA
    }

    # building cannot link lists
    # this is more efficient than reducing from a nxn binary constraint matrix
    for (i in 1:nc) {
      if (i > nc)
        break

      u <- cannot_link[i, 1]
      v <- cannot_link[i, 2]

      if (any(is.na(cannot_link_list[[u]]))) {
        cannot_link_list[[u]] <- c(v)
      } else {
        cannot_link_list[[u]] <- c(cannot_link_list[[u]], v)
      }
      if (any(is.na(cannot_link_list[[v]]))) {
        cannot_link_list[[v]] <- c(u)
      } else {
        cannot_link_list[[v]] <- c(cannot_link_list[[v]], u)
      }
    }

    collect_and_return <- function(cluster_labels) {
      if (compute_stats) {
        representatives_and_more <-
          compute_cluster_representative_and_diameter_and_cardinality(cluster_labels)
        representatives_and_more <- cbind(representatives_and_more, compute_cluster_separation(cluster_labels))
        distances_to_representative <-
          compute_cluster_representative_dist(cluster_labels, representatives_and_more)
        clusinfo <- representatives_and_more
        return(
          list(
            labels = cluster_labels,
            distances_to_representative = distances_to_representative,
            clusinfo = clusinfo
          )
        )
      } else {
        return(cluster_labels)
      }
    }

    initial_centroids <- sample(1:n, k)

    # C contains centroids
    C <- matrix(nrow = k, ncol = d)
    for (i in 1:k) {
      C[i,] <- data[initial_centroids[i],]
    }

    last_cluster_labels <- rep(0, n)
    for (iter in 1:maxiter) {
      cluster_labels <- rep(0, n)
      for (i in 1:n) {
        dist_to_centroids <- rep(1e15, k)
        best <- -1
        for (j in 1:k) {
          if (can_put_element_in_cluster(cluster_labels, cannot_link_list, i, j)) {
            dist_to_centroids[j] <- fast_dist(data[i,], C[j,])
            if (best == -1 ||
                dist_to_centroids[j] < dist_to_centroids[best]) {
              best <- j
            }
          }
        }
        if (best == -1) {
          # did not find a cluster we can put i into, abort
          return(0)
        }
        cluster_labels[i] <- best
      }
      if (iter > 1) {
        # if clusters didn't change, centroids won't update, no elements will be reassigned,
        # and we can save us any more work
        if (all(last_cluster_labels == cluster_labels)) {
          return(collect_and_return(cluster_labels))
        }
      }
      if (iter == maxiter) {
        return(collect_and_return(cluster_labels))
      }

      C2 <- matrix(0, nrow = k, ncol = d)
      dem <- rep(0, k)
      for (i in 1:n) {
        j <- cluster_labels[i]
        C2[j,] <- C2[j,] + data[i,]
        dem[j] <- dem[j] + 1
      }
      for (i in 1:k) {
        if (dem[i] > 0) {
          C[i,] <- 1.0 * C2[i,] / dem[i]
        }
      }
      last_cluster_labels <- cluster_labels
    }
  }


# https://theclevermachine.wordpress.com/2013/03/30/the-statistical-whitening-transform/
white_data <- function(x) {
  n <- nrow(x)
  # means of random vectors
  mu <- colMeans(x)

  # centered data: remove mean
  x_0 <- sweep(x,
               MARGIN = 2,
               STATS = mu,
               FUN = '-')
  # compute sample covariance matrix
  S <- (t(x_0) %*% x_0) / (n - 1)
  # compute eigenvalues
  S.evd <- eigen(S, symmetric = TRUE)

  # actual whitening: rotate around cov. eigenvectors like PCA, scale to unit variance
  # rotation matrix
  E <- S.evd$vectors
  R <- t(E)
  # scaling matrix
  D <- diag(S.evd$values)
  D.sqrt <- diag(sqrt(S.evd$values))
  D.inv.sqrt <- diag(1 / sqrt(S.evd$values))

  # whitening matrices
  s_inv_sqrt <- D.inv.sqrt %*% R
  s_sqrt <- D.sqrt %*% R

  x_w <- x_0 %*% t(s_inv_sqrt)
  colnames(x_w) <- colnames(x_0)

  return(list(
    mu = mu,
    x_0 = x_0,
    x_w = x_w,
    s_inv_sqrt = s_inv_sqrt,
    s_sqrt = s_sqrt
  ))
}

sort_by_dist <- function(X) {
  S <- X
  p <- ncol(S)
  sorted_comps <- c()
  sorted_values <- c()
  i <- 1
  while (i <= p) {
    d <- get_component_distances(S)
    colsum <- colSums(d)
    most_dissimilar <- names(which.max(colsum))[1]
    sorted_values <- c(sorted_values, unname(colsum[most_dissimilar]))
    sorted_comps <- c(sorted_comps, most_dissimilar)
    S <- select(S, -most_dissimilar)
    i <- i + 1
  }
  R <- data.frame(value=sorted_values, name=sorted_comps)
  return(R)
}

name_ts <- function(id, ts) {
  return(paste(id, ts, sep = '#'))
}

name_ts_int <- function(id, i) {
  return(paste(id, '#Series ', i, sep = ''))
}

name_ts_inv <- function(n) {
  return(unlist(strsplit(n, '#')[1]))
}

# Returns identifier for parameter combination
sobi_id <- function(k1, k2, b) {
  concat <- paste(k1, k2, sprintf("%0.2f", b), sep = '|')
  return(digest::sha1(concat))
}

# Convert string-list of numbers to int-vector
str_to_int_vector <- function(str, split = ',') {
  return(unlist(lapply(strsplit(str, split), strtoi)))
}

normalize <- function(data) {
  return((data - min(data)) / (max(data) - min(data)))
}

clip_ts <- function(timeseries, clip) {
  if (length(timeseries) <= clip) {
    return(timeseries)
  }
  return(timeseries[1:clip])
}

collect_doi <- function(results, metric, include_only = c()) {
  ids <- hash::keys(results)
  if (length(include_only) > 0) {
    ids <- include_only
  }
  n <- length(ids)
  p <- ncol(results[[ids[1]]]$S)
  res <- matrix(0, nrow = n, ncol = p)
  i <- 1
  for (id in ids) {
    m <- NA
    if (!is.null(supported_sort_metrics_fns[[metric]])) {
      m <- apply(results[[id]]$S, 2, supported_sort_metrics_fns[[metric]])
    }
    res[i, ] <- sort(m, decreasing = T)
    i <- i + 1
  }
  rownames(res) <- ids
  return(res)
}

collect_param <- function(results,
                          param = 'k1',
                          include_only = c()) {
  res <- list()
  ids <- hash::keys(results)
  if (length(include_only) > 0) {
    ids <- include_only
  }
  for (id in ids) {
    res[[id]] <- results[[id]][[param]]
  }
  return(res)
}

lagset_as_matrix <- function(sets,
                             lagbinsize = 1,
                             lag.max = 2500) {
  num_bins <- lag.max
  if (lagbinsize > 1) {
    num_bins <- lag.max %/% lagbinsize
    if (lag.max %% lagbinsize > 0) {
      num_bins <- num_bins + 1
    }
  }
  ids <- names(sets)
  vals <- matrix(0, nrow = num_bins, ncol = length(sets))
  i <- 0
  for (id in ids) {
    i <- i + 1
    lagset <- sets[[id]]
    for (bin in c(0:(num_bins - 1))) {
      min_lag <- bin * lagbinsize + 1
      max_lag <- min((bin + 1) * lagbinsize, lag.max)
      for (lag in lagset) {
        if (min_lag <= lag && lag <= max_lag) {
          vals[bin + 1, i] <- vals[bin + 1, i] + 1
        }
      }
    }
  }
  colnames(vals) <- ids
  return(t(vals))
}

coordinates_to_grid_idx <- function(coords, map_edge_length=200, cell_size=10) {
  x <- (coords[1] - cell_size / 2) / cell_size
  y <- (coords[2] - cell_size / 2) / cell_size

  grid_width <- as.integer(map_edge_length/cell_size)
  axis_length <- ceiling(grid_width/2) - 1 # half of total side length, plus a spot for zero
  # neither coordinate can be longer than half the grid width or it would be outside
  if (abs(x) > axis_length || abs(y) > axis_length) {
    stop(paste('coordinates', x, y, 'are out of bounds for grid of size', grid_width, 'with axis length', axis_length))
  }

  # coordinates can be negative and can't be used directly as grid index
  # e.g. in a 11x11 grid, 6/6 would be the origin (coords 0/0)
  origin <- ceiling(grid_width/2)
  grid_idx <- c(origin, origin) + c(-y, x) # not a mistake, column index is the x coordinate!

  return(grid_idx)
}

grid_idx_to_coordinates <- function(idx, map_edge_length=200, cell_size=10) {
  grid_width <- as.integer(map_edge_length/cell_size)
  origin <- ceiling(grid_width/2)
  minus_origin <- (idx - origin)
  col <- minus_origin[2]
  row <- minus_origin[1]
  coords <- c(col, -row) * cell_size + cell_size / 2
  return(coords)
}

# https://stackoverflow.com/questions/398299/looping-in-a-spiral
find_new_index <- function(grid, idx.old) {
  X <- ncol(grid)
  Y <- nrow(grid)
  X.search <- 2 * X
  Y.search <- 2 * Y
  dx <- 0
  dy <- -1
  x <- 0
  y <- 0
  for (i in c(1:(max(X.search, X.search) ^ 2))) {
    if ((-X.search / 2 < x &&
         x <= X.search / 2) && (-X.search / 2 < y && y <= X.search / 2)) {
      idx.new <- idx.old + c(x, y)
      if (0 < idx.new[1] && idx.new[1] <= X && 0 < idx.new[2] && idx.new[2] <= Y) {
        if (grid[idx.new[1], idx.new[2]] == 0) {
          return(idx.new)
        }
      }
    }
    if ((x == y) || (x < 0 && x == -y) || (x > 0 && x == 1 - y)) {
      a <- dx
      dx <- -dy
      dy <- a
    }
    x <- x + dx
    y <- y + dy
  }
  stop('no new index found')
}

project_embedding_for_frontend <- function(embedding, map_edge_length = 250, cell_size=5) {
  maxcoord <- max(abs(embedding))
  grid_width <- as.integer(map_edge_length/cell_size)
  axis_length <- ceiling(grid_width/2) - 1
  scale <- maxcoord / axis_length
  if (scale != 0) {
    embedding <- round(embedding / scale) * cell_size
  }
  return(list(
    embedding=embedding,
    scale=scale
  ))
}

rasterize_and_remove_overlaps <- function(embedding, cell_size = 5, map_edge_length = 250) {
  # rasterize
  embedding <- cell_size * round(embedding / cell_size) + cell_size/2
  grid_width <- as.integer(map_edge_length/cell_size)
  # make grid that tracks positions
  grid <- matrix(0, ncol = grid_width, nrow = grid_width)
  for (row in c(1:nrow(embedding))) {
    idx <- coordinates_to_grid_idx(embedding[row, ], cell_size = cell_size, map_edge_length = map_edge_length)
    grid[idx[1], idx[2]] <- grid[idx[1], idx[2]] + 1
  }

  for (i in c(1:nrow(embedding))) {
    for (j in c(1:nrow(embedding))) {
      if (i == j) {
        next

      }
      a <- embedding[i, ]
      b <- embedding[j, ]
      if (!identical(a, b)) {
        next
      }
      b.idx <- coordinates_to_grid_idx(b, cell_size = cell_size, map_edge_length = map_edge_length)
      b.idx.new <- find_new_index(grid, b.idx)
      grid[b.idx[1], b.idx[2]] <- grid[b.idx[1], b.idx[2]] - 1
      grid[b.idx.new[1], b.idx.new[2]] <-
        grid[b.idx.new[1], b.idx.new[2]] + 1
      embedding[j,] <- grid_idx_to_coordinates(b.idx.new, cell_size = cell_size, map_edge_length = map_edge_length)
    }
  }
  return(embedding)
}

print_embedding <- function(emb, edge, cell) {
  checkerboard <- matrix(0, ncol=edge/cell, nrow=edge/cell)
  for(i in 1:nrow(emb)) {
    point <- coordinates_to_grid_idx(emb[i,], map_edge_length = edge, cell_size = cell)
    checkerboard[point[1], point[2]] <- i
  }
  print(checkerboard)
}

embed <-
  function(m,
           dist_metric = 'euclidean',
           embedding_size = 200,
           grid_cell_size = 10,
           is.dissim = F) {
    dist_matrix <- m
    if (!is.dissim) {
      X <- m
      # don't know why but centering vectors makes map better
      # probs because they then don't have distances of millions of units anymore
      # if (dist_metric == 'euclidean') {
      #  X <- scale(X)
      # }
      dist_matrix <-
        philentropy::distance(
          X,
          method = dist_metric,
          diag = T,
          upper = T,
          use.row.names = T
        )
    }
    # to prevent exception we check the eigenvalues of distance matrix
    eig <- eigen(dist_matrix)
    emb <- matrix(0, ncol = 2, nrow = nrow(m))
    if (all(eig$values[1:2] != 0)) {
      emb <- MASS::isoMDS(as.matrix(dist_matrix + 1e-8), k = 2)$points
    }
    fe_emb <- project_embedding_for_frontend(emb, map_edge_length = embedding_size, cell_size = grid_cell_size)
    fe_emb.proj <- rasterize_and_remove_overlaps(fe_emb$embedding, map_edge_length = embedding_size, cell_size = grid_cell_size)
    ret <- as.data.frame(cbind(fe_emb.proj, emb))
    rownames(ret) <- rownames(dist_matrix)
    colnames(ret) <- c('x', 'y', 'ox', 'oy')
    return(list(
      embedding=ret,
      scale=fe_emb$scale
    ))
  }

# Calculate ACF
calc_acfs <- function(data, lag.max = 100) {
  acfs <-
    apply(data, 2, function(x) {
      the_acf <- acf(x, lag.max = lag.max, plot = FALSE)$acf
      return(the_acf[2:length(the_acf)]) # contains acf at 0 lag which is kinda useless
    })
  acfs <- reshape::melt(acfs, varnames = c('lag', 'variable'))
  return(acfs)
}

# Metric to quantify how close a matrix is to the identity
# 0 = very
measure_dist_to_identity <- function(M) {
  p <- ncol(M)
  return(norm(M - diag(p), type = "F"))
}

# Metric to quantify diagonality of a matrix
# 0 = very
measure_diagonality <- function(M) {
  O <- M
  diag(O) <- 0
  return(norm(O, type = "F"))
}

calc_scatter_diagonality <-
  function(autocovs, W, include_only = c()) {
    l <- autocovs
    if (length(include_only) > 0) {
      l <- autocovs[include_only]
    }
    return(lapply(l, function(M) {
      return(measure_diagonality(W %*% M %*% t(W)))
    }))
  }

calc_autocov_eigenvalue <- function(autocovs) {
  eigencovs <-
    unlist(lapply(autocovs, function(autocov) {
      return(sum(diff(sort(
        abs(eigen(autocov)$values)
      ))))
    }))
  result <-
    data.frame(matrix(cbind(
      c(1:lag.max), formatC(eigencovs, format = "e", digits = 4,)
    ), ncol = 2))
  colnames(result) <- c('lag', 'value')
  return(result)
}

# calculate autocovariance matrices
calc_autocovs <- function(data, lag.max = 100) {
  n <- nrow(data)
  p <- ncol(data)
  autocovs <- list()
  for (t in 1:lag.max) {
    R <- matrix(0, p, p)

    num_steps <- 0
    for (i in 1:n) {
      if (i + t > n) {
        break
      }
      num_steps <- num_steps + 1
      timestep1 <- data[i,]
      timestep2 <- data[i + t,]
      R <- R + tcrossprod(timestep1, timestep2)
    }
    R <- R / num_steps
    print(paste0(
      'Calculated autocov matrix for lag ',
      t,
      ' using ',
      num_steps,
      ' timesteps'
    ))
    autocovs[[t]] <- R
  }
  return(autocovs)
}

# original author: Klaus
fcc <- function(X, lag = 1) {
  p <- ncol(X)
  n <- nrow(X)
  Y <- sweep(X, 2, colMeans(X), "-")
  S <- cov(X)
  R <- matrix(0, ncol=p, nrow=p)

  if (det(S) == 0) {
    return(0)
  }

  Yt <- Y[1:(n - lag), ]
  Yti <- Y[(1 + lag):n, ]
  r <- sqrt(mahalanobis(Yt, center=FALSE, cov=S))
  Yu <- r * Yti
  R <- crossprod(Yu)/nrow(Yt)
  return(R)
}

# calculate 4th cross cumulant matrices
calc_fourthccs <- function(data, lag.max = 100) {
  fourthccs <- list()
  for (t in 1:lag.max) {
    R <- fcc(data, t)
    print(paste0(
      'Calculated 4th cross cumulant matrix for lag ',
      t
    ))
    fourthccs[[t]] <- R
  }
  return(fourthccs)
}


# Get overlap of lag and calendar granules
calc_calendar <- function(data, lag.max = 100) {
  n <- nrow(data)
  p <- ncol(data)

  granule.proximity <- data.frame(matrix(ncol = 4, nrow = 0))
  colnames(granule.proximity) <-
    c("lag", "mult", "granule", "proximity")

  for (t in 1:lag.max) {
    num_rows_in_lag <- n - t
    if (num_rows_in_lag <= 0) {
      next
    }
    lagged_timesteps <-
      data.frame("ts1" = dates.char, "ts2" = lead(dates.char, t))  %>% filter_all(all_vars(is.a(.)))
    lagged.ts2 <-
      dates.relative %>% filter(date_char %in% lagged_timesteps$ts2)
    lagged.ts1 <-
      dates.relative %>% filter(date_char %in% lagged_timesteps$ts1)

    lagged.diff <- lagged.ts2[, -1] - lagged.ts1[, -1]


    lag.proximities <- data.frame(matrix(ncol = 4, nrow = 0))
    colnames(lag.proximities) <-
      c("lag", "mult", "granule", "proximity")

    for (granule_type in c('year', 'month', 'week', 'day', 'hour', 'minute', 'second', 'millisecond'))  {
      diffs <- as.vector(tabulate(lagged.diff[, granule_type])) / num_rows_in_lag
      ndiffs <- length(diffs)
      lag.proximities <- rbind(
        lag.proximities,
        data.frame(
        lag = rep(t + ndiffs, ndiffs),
        granule = rep(granule_type, ndiffs),
        mult = c(1:length(diffs)),
        proximity = diffs)
      )
    }
    print(paste0('Calculated calendar proximity for lag ', t))
    granule.proximity <- rbind(granule.proximity, lag.proximities)
  }
  granule.proximity <-
    granule.proximity %>% group_by(mult, granule) %>% filter(proximity == max(proximity)) %>% filter(row_number() == 1)
  return(granule.proximity)
}

get_best_lag_for_granule <-
  function(granule.proximity,
           granule_param = NA,
           mult_param = NA) {
    if (is.na(granule_param) && is.na(mult_param)) {
      return(granule.proximity)
    }
    result <- granule.proximity
    if (!is.na(granule_param)) {
      result <- result %>% filter(granule == granule_param)
    }
    if (!is.na(mult_param)) {
      result <- result %>% filter(mult == mult_param)
    }
    if (nrow(result) == 0) {
      return(list())
    }
    return(result)
  }

get_components_correlation <- function(components) {
  component_names <- colnames(components)

  correlation_matrix <- outer(component_names, component_names, Vectorize(function(ts1_id, ts2_id) {
    if (ts1_id == ts2_id) {
      return(1)
    }
    ts1 <- components[, ts1_id]
    ts2 <- components[, ts2_id]
    pearson <- cor.test(ts1, ts2)
    return(pearson$estimate)
  }))
  colnames(correlation_matrix) <- component_names
  rownames(correlation_matrix) <- component_names
  return(correlation_matrix)
}

get_component_distances <- function(components) {
  component_names <- colnames(components)

  dist_fn <- function(ts1_id, ts2_id) {
    if (ts1_id == ts2_id) {
      return(0)
    }
    ts1 <- components[, ts1_id]
    ts2 <- components[, ts2_id]
    dist_reg <- dist(rbind(ts1, ts2))[1]
    return(dist_reg)
  }

  distance_matrix <-
    outer(component_names, component_names, Vectorize(dist_fn))
  colnames(distance_matrix) <- component_names
  rownames(distance_matrix) <- component_names
  return(as.data.frame(distance_matrix))
}

update_w_hat_simil <- function(simil, id, w) {
  if (length(simil$all_w_ids) == 0) {
    d <- data.frame(matrix(
      nrow = 1,
      ncol = 1,
      data = c(0)
    ))
    rownames(d) <- c(id)
    colnames(d) <- c(id)
    return(list(
      all_w_ids = c(id),
      all_w = w,
      normalized_w = w,
      distances = d
    ))
  }
  new_w <- rbind(simil$all_w, w)
  new_ids <- c(simil$all_w_ids, id)
  p <- ncol(new_w)
  nn <- nrow(new_w)
  n <- nn / p

  # factor_inv <- outer(c(1:nn), c(1:nn), Vectorize(function(i, j) {
  #   if (i == j) {
  #     return(F);
  #   }
  #
  #   c1 <- new_w[i, ]
  #   c2 <- new_w[j, ]
  #
  #   d_inv <- dist(rbind(c1,-c2))[1]
  #   d_reg <- dist(rbind(c1, c2))[1]
  #
  #   if (d_inv < inverse_factor_threshold) {
  #     return(T)
  #   }
  #   return(F)
  # }))

  # factor_inv <- unique(t(apply(which(factor_inv == T, arr.ind = T), 1, sort)))
  normalized_w <- new_w
  # if (nrow(factor_inv) > 0) {
  #   for (i in 1:nrow(factor_inv)) {
  #     row <- factor_inv[i,1]
  #     col <- factor_inv[i,2]
  #     # avoid normalizing more than once and thereby undoing it
  #     if (col > (nn - p) || row > (nn - p)) {
  #       prior_comp <- min(col, row)
  #       later_comp <- max(col, row)
  #       normalized_w[later_comp] <- -normalized_w[later_comp]
  #       print(paste('normalization hit (factor)', prior_comp, later_comp))
  #     }
  #   }
  # }

  # recomputing existing values that didn't change, but no special handling of (non-)commutativity of JADE::MD()
  # should this become a problem we can look up old values from simil$distances
  w_dists <- outer(c(1:n), c(1:n), Vectorize(function(i, j) {
    a <- i - 1
    b <- j - 1
    a_idxs <- seq(a*p+1, (a+1)*p)
    b_idxs <- seq(b*p+1, (b+1)*p)

    A <- normalized_w[a_idxs, ]
    B <- normalized_w[b_idxs, ]
    return(JADE::MD(A, solve(B)))
  }))
  # add new distance
  rownames(w_dists) <- new_ids
  colnames(w_dists) <- new_ids
  return(
    list(
      all_w_ids = new_ids,
      distances = as.data.frame(w_dists),
      normalized_w = normalized_w,
      all_w = new_w
    )
  )
}

build_cluster_constraints <- function(components, p) {
  num_comps <- nrow(components)
  num_results <- num_comps/p

  num_cannot_links <- p*(p-1)/2
  cannot_link <- matrix(0, ncol=2, nrow=num_results*num_cannot_links)
  for (i in 1:num_results) {
    cannot_link[c((1 + (i-1) * num_cannot_links):(num_cannot_links*i)),] <- t(combn(1:p, 2)) + (i-1) * p
  }
  return(cannot_link)
}

get_clustering_guidance <- function(components, p, time_budget_secs=30) {
  # note that components is here as row vectors
  num_comps <- nrow(components)
  num_results <- num_comps / p
  cannot_link <- build_cluster_constraints(components, p)
  hard_min <- p # cannot produce less than this many clusters
  hard_max <- num_comps - 1 # we cannot produce more clusters than this
  useful_max <- min( min(num_results, 5) * p - 1, hard_max) # the max we display

  k <- hard_min - 1
  total_elapsed_secs <- 0
  guidance_values <- rep(NA, useful_max)
  while (total_elapsed_secs < time_budget_secs && num_results > 1 && k < useful_max) {
    k <- k + 1
    i <- k - p + 1
    tictoc::tic(paste('COP-PAM, k =', k, 'of', useful_max))
    clusters <- cop_pam(1-abs(all_components_corr),
                        cannot_link,
                        k,
                        diss=T,
                        compute_stats = T)
    if (typeof(clusters) == 'list') {
      guidance_values[i] <- mean(clusters$clusinfo[,4], na.rm = T)
    }
    t <- tictoc::toc()
    elapsed_secs <- unname(t$toc - t$tic)
    total_elapsed_secs <- total_elapsed_secs + elapsed_secs
  }
  return(guidance_values)
}

update_components_based_on_corr <- function(data, components, corrs) {
  p <- ncol(data)
  nn <- ncol(components)

  inverse.components <- which(corrs < negative_corr_threshold, arr.ind = T)
  if (nrow(inverse.components) < 1) {
    return(list(
      components=components,
      corrs=corrs
    ))
  }
  iterate <- unique(t(apply(inverse.components, 1, sort)))
  for (i in 1:nrow(iterate)) {
    row <- inverse.components[i,1]
    col <- inverse.components[i,2]
    if (col > (nn - p) || row > (nn - p)) {
      later_comp <- max(col, row)
      prior_comp <- min(col, row)
      components[,later_comp] <- -components[,later_comp]
      new_corr <- unname(cor.test(components[,later_comp], components[,prior_comp])$estimate)
      corrs[prior_comp, later_comp] <- new_corr
      corrs[later_comp, prior_comp] <- new_corr
      print(paste('normalization hit (shape)', colnames(components)[prior_comp], colnames(components)[later_comp]))
    }
  }
  return(list(
    components=components,
    corrs=corrs
  ))
}

#### GLOBAL STATE

# All the results: parameters, mixing matrix, other info
results <- hash::hash()
# Dissimilarity information for mixing matrices
w_hat_simil <- list(
  all_w = matrix(ncol = ncol(dataset), nrow = 0),
  distances = matrix(ncol = 0, nrow = 0),
  all_w_ids = c()
)
# Matrix with components as columns
all_components <- matrix(ncol = 0, nrow = nrow(dataset))
all_components_corr <- matrix(ncol = 0, nrow = 0)
all_components_dist <- matrix(ncol = 0, nrow = 0)
all_clusters <- list()

# pearson correlation between components must be smaller than this to consider them same
negative_corr_threshold <- -0.9 # gut feeling and based on conversation with christoph
# euclidean distance between a component (factors) and anothers inverse needs to be smaller than this to consider them "same"
inverse_factor_threshold <- ncol(dataset)/100 # equals euclidean distance of a difference of 0.1 in every factor
lag_support_frac <- 1 / 4  # a lag worth analysing must contain at least this fraction of points
lag.max <- nrow(dataset) - floor(nrow(dataset) * lag_support_frac)
guidance.acfs <-
  calc_acfs(dataset, lag.max = lag.max)
guidance.autocovs <-
  calc_autocovs(dataset, lag.max = lag.max)
guidance.autocov_eigenvalue <-
  calc_autocov_eigenvalue(guidance.autocovs)
guidance.fourthccs <- calc_fourthccs(dataset, lag.max = lag.max)
guidance.calendar <-
  calc_calendar(dataset, lag.max = lag.max)
guidance.clustering <- character()

run_sobi <- function(data,
                     k1 = '1,2,3,4,5,6,7,8,9,10,11,12',
                     k2 = '1,2,3',
                     b = 0.9,
                     eps = 1e-03,
                     maxiter = 1e+03,
                     time_budget_secs = 20) {
  data_w <- data
  id <- sobi_id(k1, k2, b)
  k1 <- str_to_int_vector(k1)
  k2 <- str_to_int_vector(k2)

  k1_str <- paste(k1, collapse = ',')
  k2_str <- paste(k2, collapse = ',')
  if (b == 0){
    k1_str <- '[unused]'
  }
  if (b == 1) {
    k2_str <- '[unused]'
  }

  print(paste('id', id))
  print(paste('b', b))
  print(paste('k1', k1_str))
  print(paste('k2', k2_str))
  print(paste('eps', eps))
  print(paste('maxiter', maxiter))
  print(paste('time_budget_secs', time_budget_secs))

  tictoc::tic('SOBI')
  sobi <- tryCatch({
    list(
      success = T,
      result = tsBSS::gSOBI(
        data_w,
        k1 = k1,
        k2 = k2,
        b = b,
        eps = eps,
        maxiter = maxiter,
        ordered = T
      )
    )
  }, error = function(e) {
    return(list(success = F))
  })
  tictoc::toc()
  if (sobi$success) {
    sobi <- sobi$result
    p <- ncol(sobi$S)
    n <- nrow(sobi$S)
    S <- as.data.frame(sobi$S, row.names = dates.char)

    # Update distance matrix
    tictoc::tic('Update distance matrices')
    w_hat_simil <<- update_w_hat_simil(w_hat_simil, id, sobi$W)
    num_results <- length(get_success_results()) + 1
    nn <- num_results * p
    this_normalized_w <- w_hat_simil$normalized_w[c((nn - p + 1):nn), ]
    this_normalized_w_std <- this_normalized_w %*% dataset.SD
    normalized_s <- as.data.frame(tcrossprod(data_w, this_normalized_w),
                                  row.names = dates.char,
                                  col.names = colnames(S))

    # Add components to global structure for fast lookup
    ts_names <-
      lapply(colnames(S), function(ts) {
        return(name_ts(id, ts))
      })
    colnames(normalized_s) <- ts_names
    all_components <<- cbind(all_components, normalized_s)
    all_components_corr <<- get_components_correlation(all_components)
    all_components_dist <<- get_component_distances(all_components)
    new_data <- update_components_based_on_corr(dataset, all_components, all_components_corr)
    all_components <<- new_data$components
    all_components_corr <<- new_data$corrs
    normalized_s <- all_components[, c((nn - p + 1):nn)]
    tictoc::toc()

    tictoc::tic(paste('Clustering guidance with time budget', time_budget_secs, 'secs'))
    guidance.clustering <<- get_clustering_guidance(t(all_components), p, time_budget_secs=time_budget_secs)
    tictoc::toc()

    # Sort components by different metrics
    tictoc::tic('Compute sortings')
    sortings <- list()
    for (metric in supported_sort_metrics) {
      m <- NA
      if (!is.null(supported_sort_metrics_fns[[metric]])) {
        m <- apply(normalized_s, 2, supported_sort_metrics_fns[[metric]])
      } else {
        m <- figure_sort_metric_out_from_sobi_result(id, metric, sobi)
      }
      components <-
        reshape::melt(m) %>% rownames_to_column(var = 'name') %>% dplyr::arrange(-value)
      sortings[[metric]] <- list(vector = sort(m, decreasing = T),
                                 components = components)
    }
    sorted_by_dist <- sort_by_dist(normalized_s)
    sortings$dist <- list(vector = sorted_by_dist$value, components = sorted_by_dist)
    tictoc::toc()

    # Calculate how well unmixing matrix diagonalizes the scatters
    # Model assumption tells us their expecation should be perfectly diagonal
    tictoc::tic('Compute scatter diagonality and autocov difference')
    autocov_diag <-
      calc_scatter_diagonality(guidance.autocovs, sobi$W)
    fourthcc_diag <-
      calc_scatter_diagonality(guidance.fourthccs, sobi$W)

    # Calculate difference in ACF for components
    # Expert recommendation is that lags should be picked such that temporal correlation is most different for Z
    acfs <- purrr::reduce(c(1:p), function(agg, col) {
      cf <- acf(S[, col], lag.max = lag.max, plot = F)
      cf <- unlist(cf$acf, use.names = F)
      # Drop lag 0, we never care about it anywhere
      cf <- cf[2:length(cf)]
      return(cbind(agg, as.double(cf)))
    }, .init = matrix(ncol = 0, nrow = lag.max))
    colnames(acfs) <- colnames(S)
    acf_diff <- unlist(purrr::map(c(1:nrow(acfs)), function(r) {
      roww <- unlist(S[r, ], use.names = F)
      d <- sum(abs(diff(sort(
        roww, decreasing = TRUE
      ))))
      return(d)
    }), use.names = F)
    tictoc::toc()

    # Pack everything up and save
    results[[id]] <-
      hash::hash(
        success = T,
        sobi = sobi,
        p = p,
        n = n,
        k1 = k1,
        k2 = k2,
        b = b,
        S = normalized_s,
        Sorig = S,
        W = this_normalized_w,
        W_std = this_normalized_w_std,
        sortings = sortings,
        model_diag = list(
          autocov = autocov_diag,
          fourthcc = fourthcc_diag
        ),
        # exp_model_diag = exp_model_diag,
        # exp_model_ident = exp_model_ident,
        acf_diff = acf_diff,
        eps = eps,
        maxiter = maxiter
      )
  } else {
    results[[id]] <-
      hash::hash(
        success = F,
        k1 = k1,
        k2 = k2,
        b = b,
        eps = eps,
        maxiter = maxiter
      )
  }
  return(id)
}

is_success_result <- function(id) {
  return(results[[id]]$success)
}

get_success_results <- function() {
  return(purrr::keep(hash::keys(results), is_success_result))
}

#### RESULT INIT


# TODO add error handling
# failing parameters:
# [1] "Latin hypercube param #5"
# [1] "b 0"
# [1] "k1 1,2,3,4,5,57,145,146,262,405,710,720,793,950,1252,1384,1448,1898,2116,2127,2166,2169,2189,2471,2490"
# [1] "k2 1,2,3,282,382,392,609,627,697,984,1189,1244,1274,1331,1337,1502,1634,1661,1682,1743,1787,1846,2311"

prepare_results <- function(lag.max, N=1, time_budget_secs = 30) {
  # Tang et al. 2005 "standard set"
  print('Standard set...')
  run_sobi(
    dataset.zoo,
    k1 = '1,2,3,4,5,6,7,8,9,10,12,14,16,18,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100,120,140,160,180,200,220,240,260,280,300',
    time_budget_secs = time_budget_secs)
  # No quadratic autocorrelation
  print('No quadratic autocorrelation...')
  run_sobi(dataset.zoo, b = 1, time_budget_secs = time_budget_secs)
  # No linear autocorrelation
  print('No linear autocorrelation...')
  run_sobi(dataset.zoo, b = 0, time_budget_secs = time_budget_secs)

  #print('Failing exrates combination')
  #run_sobi(dataset.zoo,
  #         b = 0,
  #         k1 = '1',
  #         k2 = '1,2,3,282,382,392,609,627,697,984,1189,1244,1274,1331,1337,1502,1634,1661,1682,1743,1787,1846,2311',
  #         time_budget_secs = 0)

  if (N == 0) {
    return()
  }

  k_lag <- 20
  k <- k_lag * 2 + 3

  x <- lhs::randomLHS(N, k)
  y <- x

  # b
  y[, 1] <- round(x[, 1], digits = 2) # TODO use qunif?
  # num k1
  y[, 2] <-  ceiling(qunif(x[, 2], 0, k_lag))
  # num k2
  y[, 3] <-  ceiling(qunif(x[, 3], 0, k_lag))
  # k1 and k2
  for (i in 4:k) {
    y[, i] <- ceiling(qunif(x[, i], 0, lag.max))
  }

  for (i in 1:N) {
    b <- y[i, 1]
    k1_idx_start <- 4
    k2_idx_start <- k_lag + 4
    k1_idxs <- seq(k1_idx_start, k1_idx_start + y[i, 2] - 1)
    k2_idxs <- seq(k2_idx_start, k2_idx_start + y[i, 3] - 1)
    k1 <- unique(sort(c(y[i, k1_idxs])))
    k2 <- unique(sort(c(y[i, k2_idxs])))

    print(paste('Latin hypercube param #', i, sep = ''))

    k1_str <- paste(k1, collapse = ',')
    k2_str <- paste(k2, collapse = ',')
    run_sobi(dataset.zoo,
             b = b,
             k1 = k1_str,
             k2 = k2_str,
             time_budget_secs = time_budget_secs)
  }
}

#### API FUNCTIONS

#* @filter cors
cors <- function(req, res) {
  res$setHeader("Access-Control-Allow-Methods", "*")
  res$setHeader("Access-Control-Allow-Headers", "*")
  res$setHeader("Access-Control-Allow-Origin", "*")
  if (req$REQUEST_METHOD == 'OPTIONS') {
    res$status <- 200
    return()
  } else {
    plumber::forward()
  }

}

#* @get /data/metadata/size
function() {
  return(c(length(rownames(dataset)), length(colnames(dataset))))
}

#* @get /data/metadata/colnames
function() {
  return(colnames(dataset))
}

#* @get /data/metadata/rownames
function() {
  return(rownames(dataset))
}

#* Returns single data column, possibly windowed by row index `from`/`to`
#* @get /data/column/<col>
#* @param from:int
#* @param to:int
function(col, from = NA, to = NA) {
  n <- nrow(dataset)
  d <-
    data.frame(matrix(cbind(c(1:n), dataset[, col], rownames(dataset)), ncol = 3))
  colnames(d) <- c('rownum', 'value', 'date')

  if (identical(from, NA)) {
    from <- 1
  }
  if (identical(to, NA)) {
    to <- n
  }
  return(d %>% slice(from:to))
}

#* Runs gSOBI once with given parameters
#* @post /gsobi
#* @param k1 linear autocorrelation lag set
#* @param k2 quadratic autocorrelation lag set
#* @param b:double weight
#* @param eps:double epsilon
#* @param maxiter:int max iterations
function(k1 = '1,2,3,4,5,6,7,8,9,10,11,12',
         k2 = '1,2,3',
         b = 0.9,
         eps = 1e-03,
         maxiter = 1000) {
  return(run_sobi(
    dataset.zoo,
    k1 = k1,
    k2 = k2,
    b = b,
    eps = eps,
    maxiter = maxiter
  ))
}

#* Returns result IDs
#* @get /gsobi
function() {
  r <- list()
  for (id in hash::keys(results)) {
    r[[id]] = list(
      id=id,
      success=results[[id]]$success,
      k1=results[[id]]$k1,
      k2=results[[id]]$k2,
      b=results[[id]]$b,
      maxiter=results[[id]]$maxiter,
      eps=results[[id]]$eps
    )
  }
  return(r)
}

#* Returns parameters of past run with given ID
#* @get /gsobi/<id>/params
function(id) {
  params <- list()
  params[['k1']] <- results[[id]]$k1
  params[['k2']] <- results[[id]]$k2
  params[['b']] <- results[[id]]$b
  params[['maxiter']] <- results[[id]]$maxiter
  params[['eps']] <- results[[id]]$eps
  return(params)
}

#* Returns mixing matrix of past run with given ID
#* @get /gsobi/<id>/w
function(id) {
  if (!is_success_result(id)) {
    stop('run was not successful')
  }
  return(list(W=results[[id]]$W, W_std=results[[id]]$W_std))
}

#* Returns linear autocorrelation p values of past run with given ID
#* @get /gsobi/<id>/linp
function(id) {
  if (!is_success_result(id)) {
    stop('run was not successful')
  }
  return(results[[id]]$sobi$linP)
}

#* Returns quadratic autocorrelation p values of past run with given ID
#* @get /gsobi/<id>/volp
function(id) {
  if (!is_success_result(id)) {
    stop('run was not successful')
  }
  return(results[[id]]$sobi$volP)
}

#* Returns latent components of past run with given ID
#* @get /gsobi/<id>/s
function(id) {
  if (!is_success_result(id)) {
    stop('run was not successful')
  }
  return(results[[id]]$S)
}

#* Returns fitness for other lags of result of past run with given ID
#* @get /gsobi/<id>/model
function(id) {
  if (!is_success_result(id)) {
    stop('run was not successful')
  }
  return(
    list(
      model_diag = list(
        autocov = clip_ts(results[[id]]$model_diag$autocov, lag.max),
        fourthcc = clip_ts(results[[id]]$model_diag$fourthcc, lag.max)
      ),
      exp_model_diag = results[[id]]$exp_model_diag,
      exp_model_ident = results[[id]]$exp_model_ident,
      acf_diff = clip_ts(results[[id]]$acf_diff, lag.max)
    )
  )
}

#* Returns sort orders of components from run with given ID, according to different measures
#* @get /gsobi/<id>/sortings
function(id) {
  if (!is_success_result(id)) {
    stop('run was not successful')
  }
  return(results[[id]]$sortings)
}

#* Downloads .RData file of a result
#* @get /gsobi/<id>/download
#* @serializer contentType list(type="application/octet-stream")
function(id, res) {
  success <- results[[id]]$success

  parameters <- list(
    k1=results[[id]]$k1,
    k2=results[[id]]$k2,
    b=results[[id]]$b,
    maxiter=results[[id]]$maxiter,
    eps=results[[id]]$eps
  )
  components_colwise <- NULL
  W <- NULL
  if (success) {
    components_colwise <- results[[id]]$Sorig
    W <- results[[id]]$W
  }

  tf <- tempfile(pattern=id, fileext='.RData')
  save(parameters, components_colwise, W, file=tf)
  res$headers[['Content-Disposition']] <- paste('attachment; filename="',id,'.RData"', sep='')
  return(readBin(tf, "raw", n = file.info(tf)$size))
}


#* Returns MDS coordinates for results on 2D
#* @get /gsobi/result-embeddings
#* @param similarity 'shape' or 'doi'
#* @param comparison_strategy compare 'all' or just n-th ('rank') components
#* @param compare_rank:int rank to compare when comparison_strategy == 'rank'
#* @param sort_by which DOI function to sort with
function(similarity='doi', sort_by='kurtosis', comparison_strategy='all', compare_rank=0) {
  compare_rank <- as.integer(compare_rank)
  p <- ncol(dataset)
  success_ids <- get_success_results()

  if (comparison_strategy == 'all') {
    # for every result, compare all components with each other
    if (similarity == 'doi') {
      R <- matrix(nrow = 0, ncol = p)
      for (id in success_ids) {
        R <- rbind(R, results[[id]]$sortings[[sort_by]]$vector)
      }
      rownames(R) <- success_ids
      d <-
        as.data.frame(
          philentropy::distance(
            R,
            method = 'manhattan',
            diag = T,
            upper = T,
            use.row.names = T
          )
        )
      colnames(d) <- success_ids
      rownames(d) <- success_ids
      e <- embed(d, is.dissim = T)
      return(list(embedding = e$embedding, scale=e$scale,
                  distances = normalize(d)))
    } else if (similarity == 'shape') {
      d <- matrix(0, nrow=length(success_ids), ncol=length(success_ids))
      for(i in 1:nrow(d)) {
        for (j in 1:ncol(d)) {
          if (i == j || d[i,j] > 0) {
            next
          }

          r1 <- success_ids[i]
          r2 <- success_ids[j]

          r1ts <- generate_result_ts_ids(r1)
          r2ts <- generate_result_ts_ids(r2)

          # dists <- all_components_dist[r1ts, r2ts]
          dists <- 1 - abs(all_components_corr[r1ts, r2ts])
          diff <- sum(apply(dists, 1, min))

          d[i,j] <- diff
          d[j,i] <- diff
        }
      }
      colnames(d) <- success_ids
      rownames(d) <- success_ids
      e <- embed(d, is.dissim=T)
      return(list(embedding = e$embedding, scale=e$scale,
                  distances = normalize(as.data.frame(d))))
    } else {
      stop(paste('unsupported similarity measure for embedding:', similarity))
    }
  } else if (comparison_strategy == 'rank') {
    if (similarity == 'doi') {
      d <- matrix(0, ncol=length(success_ids), nrow=length(success_ids))
      for (i in 1:nrow(d)){
        for (j in 1:ncol(d)) {
          if (i == j || d[i,j] > 0) {
            next
          }

          c_1 <- results[[success_ids[i]]]$sortings[[sort_by]]$vector[compare_rank]
          c_2 <- results[[success_ids[j]]]$sortings[[sort_by]]$vector[compare_rank]
          d[i,j] <- abs(c_1 - c_2)
        }
      }
      colnames(d) <- success_ids
      rownames(d) <- success_ids
      e <- embed(d, is.dissim = T)
      return(list(embedding = e$embedding, scale=e$scale,
                  distances = normalize(as.data.frame(d))))
    } else if (similarity == 'shape') {
      d <- matrix(0, nrow=length(success_ids), ncol=length(success_ids))
      for(i in 1:nrow(d)) {
        for (j in 1:ncol(d)) {
          if (i == j || d[i,j] > 0) {
            next
          }

          c_1 <- results[[success_ids[i]]]$sortings[[sort_by]]$components$name[compare_rank]
          c_2 <- results[[success_ids[j]]]$sortings[[sort_by]]$components$name[compare_rank]
          # diff <- all_components_dist[c_1, c_2]
          diff <- 1 - abs(all_components_corr[c_1, c_2])
          d[i,j] <- diff
          d[j,i] <- diff
        }
      }
      colnames(d) <- success_ids
      rownames(d) <- success_ids
      e <- embed(d, is.dissim=T)
      return(list(embedding = e$embedding, scale=e$scale,
                  distances = normalize(as.data.frame(d))))
    } else {
      stop(paste('unsupported similarity measure for embedding:', similarity))
    }
  }

  stop(paste('unsupported comparison strategy for embedding:', comparison_strategy))
}

#* Returns (MD-index) distance matrix between all W's
#* @get /gsobi/w-hat-distances
function() {
  return(w_hat_simil$distances)
}

#* Returns component correlations
#* @get /gsobi/component-correlations
function() {
  return(list(
    rownames=rownames(all_components_corr),
    data=as.matrix(all_components_corr)
  ))
}

#* Returns component distances
#* @get /gsobi/component-distances
function() {
  return(list(
    rownames=rownames(all_components_dist),
    data=as.matrix(all_components_dist)
  )
  )
}

#* Returns MDS coordinates for parameter on 2D
#* @get /gsobi/parameter-embeddings
#* @param lagbinsize:int binsize of lags
function(lagbinsize = 1) {
  lagbinsize <- as.integer(lagbinsize)
  k1 <-
    lagset_as_matrix(collect_param(results, 'k1'), lagbinsize, lag.max)
  k2 <-
    lagset_as_matrix(collect_param(results, 'k2'), lagbinsize, lag.max)

  k1_dist <-
    as.data.frame(philentropy::distance(
      k1,
      method = 'manhattan',
      upper = T,
      diag = T,
      use.row.names = T
    ))
  k2_dist <-
    as.data.frame(philentropy::distance(
      k2,
      method = 'manhattan',
      upper = T,
      diag = T,
      use.row.names = T
    ))

  rownames(k1_dist) <- hash::keys(results)
  colnames(k2_dist) <- hash::keys(results)

  k1_embed <- embed(k1_dist, is.dissim = T)
  k2_embed <- embed(k2_dist, is.dissim = T)

  return(list(
    k1 = list(embedding = k1_embed$embedding,
              scale=k1_embed$scale,
              distances = normalize(k1_dist)),
    k2 = list(embedding = k2_embed$embedding,
              scale=k2_embed$scale,
              distances = normalize(k2_dist))
  ))
}

generate_result_ts_ids <- function(result_id) {
  p <- ncol(dataset)
  ids <- c()
  for (i in 1:p) {
    ids <- c(ids, name_ts_int(result_id, i))
  }
  return(ids)
}

#* Returns medoids for a set of results
#* @get /gsobi/components/intra-medoids
#* @param k:int how many clusters
function(result_ids='', k=1) {
  p <- ncol(dataset)
  k <- as.integer(k)
  result_ids <- unlist(strsplit(result_ids, split=','))
  success_results <- get_success_results()
  result_ids <- success_results[success_results %in% result_ids]

  ret <- list()
  for (r in result_ids) {
    ret[[r]] <- list()
  }

  for (result_id in result_ids) {
    result_ts_ids <- generate_result_ts_ids(result_id)
    if (k < p) {
      dists <- all_components_dist[result_ts_ids, result_ts_ids]
      clustering <- cluster::pam(dists, k=k, diss=T, pamonce=5)
      medoids <- clustering$medoids
      for(i in 1:k) {
        medoid <- medoids[i]
        components <- names(clustering$clustering)[clustering$clustering %in% c(i)]
        ret[[result_id]][[i]] <- components
      }
    } else {
      ret[[result_id]] <- list(result_ts_ids)
    }
  }
  return(ret)
}


#* Returns clustered components along with stability etc
#* @get /gsobi/components/inter-medoids
#* @param k:int how many clusters
function(k = 0) {
  k <- as.integer(k)
  p <- ncol(dataset)
  nn <- ncol(all_components)
  # if no cluster parameter is provided we take first possible ones
  if (k == 0) {
    k <- p
  }
  if (k < p || k > nn) {
    stop(paste('clustering parameter must be between',p,'and',nn, ", but was", k))
  }
  constraints <- build_cluster_constraints(t(all_components), p)
  all_clusters <<- cop_pam(1-abs(all_components_corr), constraints, k, diss=T, compute_stats=T)
  guidance.clustering[k - p + 1] <<- mean(all_clusters$clusinfo[,4], na.rm = T)

  medoids <- list()
  comp_names <- colnames(all_components) %>% map(name_ts_inv)
  # collect cluster medoids and metrics
  for (i in c(1:k)) {
    medoid_idx <- all_clusters$clusinfo[i,1]
    if (medoid_idx == 0) {
      # cluster can be empty
      next
    }
    time_series_idxs <- which(all_clusters$labels %in% c(i))
    time_series <- map(time_series_idxs, function(x) {return(comp_names[[x]])})

    medoid_ids <- comp_names[[medoid_idx]]
    medoid_result_id <- medoid_ids[1]
    medoid_ts_id <- medoid_ids[2]

    results_in_cluster <- purrr::map(time_series, function(ts) {
      return(ts[1])
    }) %>% unique() %>% unlist()

    #parameter_histograms <-
    #  purrr::reduce(results_in_cluster, function(agg, result_id) {
    #    result_idx <- match(c(result_id), results_in_cluster)[1]
    #
    #    # b
    #    b <- results[[result_id]]$b
    #    b_idx <- 1 + 10 * b
    #    agg$b[b_idx] <- agg$b[b_idx] + 1
    #
    #    # k1
    #    k1 <- results[[result_id]]$k1
    #    for (lag in k1) {
    #      agg$k1[lag] <- agg$k1[lag] + 1
    #    }
    #
    #    # k2
    #    k2 <- results[[result_id]]$k2
    #    for (lag in k2) {
    #      agg$k2[lag] <- agg$k2[lag] + 1
    #    }
    #
    #    return(agg)
    #  }, .init = list(
    #    k1 = numeric(lag.max),
    #    k2 = numeric(lag.max),
    #    b = numeric(11)
    #  ))


    components <- lapply(1:length(time_series_idxs), function(i) {
      ts_idx <- time_series_idxs[i]
      ids <- time_series[[i]]
      result_id <- ids[1]
      ts_id <- ids[2]
      dist_to_medoid <- 1-abs(all_components_corr[medoid_idx, ts_idx])

      return(list(
        dist_to_medoid = dist_to_medoid,
        time_series = list(result_id = result_id,
                           ts_id = ts_id)
      ))
    })

    medoids[[i]] <- list(
      medoid = list(result_id = medoid_result_id,
                    ts_id = medoid_ts_id),
      # parameter_histograms = parameter_histograms,
      # results_in_cluster = results_in_cluster,
      components = components
    )
  }

  return(medoids)
}

#* Returns ranks for cluster medoids
#* @get /gsobi/components/ranks/<metric>
function(metric) {
  comp_names <- colnames(all_components) %>% map(name_ts_inv)
  ranks <- list()
  k <- nrow(all_clusters$clusinfo)

  for (i in c(1:k)) {
    medoid_idx <- all_clusters$clusinfo[i,1]
    medoid_ids <- comp_names[[medoid_idx]]
    time_series_idxs <- which(all_clusters$labels %in% c(i))
    time_series <- map(time_series_idxs, function(x) {return(comp_names[[x]])})

    ranks[[i]] <- list(
      medoid = list(result_id = medoid_ids[1],
                    ts_id = medoid_ids[2]),
      components = lapply(time_series, function(ts) {
        result_id <- ts[1]
        ts_id <- ts[2]
        rank <-
          which(results[[result_id]]$sortings[[metric]]$components$name == name_ts(result_id, ts_id))
        return(list(
          time_series = list(result_id = result_id,
                             ts_id = ts_id),
          rank = rank
        ))
      })
    )
  }
  return(ranks)
}


### ==== GUIDANCE ====

#* Gets current guidance config (lag)
#* @get /guidance
function() {
  params <- list(lag = lag.max,
                 col = colnames(dataset)[1])
  return(params)
}

#* Initialises guidance data up to provided lag
#* @post /guidance
#* @param lag:int max lag
function(lag) {
  lag <- strtoi(lag) # why
  lag.max <<- lag
  return()
}

#* Changes sign of a component
#* @post /invert
#* @param seriesName
function(seriesName) {
  all_components[, seriesName] <<- -all_components[,seriesName]
  all_components_corr <<- get_components_correlation(all_components)
  all_components_dist <<- get_component_distances(all_components)
  return()
}

#* Returns ACF for one or all variables
#* @get /guidance/acf
#* @param column
function(column = NA) {
  if (identical(NA, guidance.acfs)) {
    stop("Guidance not initialized")
  }
  if (!identical(NA, column)) {
    return(subset(guidance.acfs, variable == column))
  }
  return(guidance.acfs)
}

#* Returns calendar overlap for granule desired granule
#* @get /guidance/calendar
#* @param granule desired granule
#* @param mult:int desired multiplicity of granule
function(granule = NA, mult = NA) {
  if (identical(NA, guidance.calendar)) {
    stop("Guidance not initialized")
  }
  return(get_best_lag_for_granule(guidance.calendar, granule, as.integer(mult)))
}

#* Returns calendar granule for all lags
#* @get /guidance/calendar-granule
function() {
  if (identical(NA, guidance.calendar)) {
    stop("Guidance not initialized")
  }
  points <-
    guidance.calendar %>% dplyr::group_by(lag) %>% dplyr::filter(proximity == max(proximity)) %>% dplyr::arrange(lag)

  return(points)
}

#* Returns autocovariance matrices
#* @get /guidance/autocov
function() {
  if (identical(NA, guidance.autocovs)) {
    stop("Guidance not initialized")
  }
  return(guidance.autocovs)
}

#* Returns autocovariance matrix info
#* @get /guidance/autocov-eigenvalue
function() {
  if (identical(NA, guidance.autocov_eigenvalue)) {
    stop("Guidance not initialized")
  }
  return(guidance.autocov_eigenvalue)
}

#* Returns clustering guidance
#* @get /guidance/clustering
function() {
  return(guidance.clustering)
}

#* Returns lag bin importance to explain difference in results
#* @get /guidance/lag-bin-weights
#* @param lagbinsize:int the bin size
#* @param result_ids result ids comma separated
function(lagbinsize = 1,
         result_ids = '') {
  result_ids <- unlist(strsplit(result_ids, split = ','))
  n <- length(result_ids)
  lagbinsize <- as.integer(lagbinsize)
  result <- list()

  if (n < 2) {
    return(result)
  }

  for (metric in supported_sort_metrics) {
    result[[metric]] <- list()

    doi_values <-
      scale(collect_doi(results, metric, include_only = result_ids))
    doi_dist <-
      philentropy::distance(doi_values,
                            method = 'euclidean',
                            diag = T,
                            upper = T)


    for (p in c('k1', 'k2')) {
      # TODO needs check on `b` parameter if the lag set was even used
      param_values <-
        lagset_as_matrix(
          collect_param(results, p, include_only = result_ids),
          lagbinsize = lagbinsize,
          lag.max = lag.max
        )
      nn <- (n - 1) / 2 * n
      m <- ncol(param_values)

      if (n == 2) {
        delta <- c(doi_dist)
        X <- param_values[1, ] - param_values[2, ]
      } else {
        delta <- numeric(nn)
        X <- matrix(0, nrow = nn, ncol = m)
        iteration <- 0
        for (i in 1:n) {
          for (j in 1:n) {
            if (lower.tri(doi_dist)[i, j] == T) {
              iteration <- iteration + 1
              delta[iteration] <- doi_dist[i, j]
              for (k in 1:ncol(X)) {
                X[iteration, k] <- (param_values[i, k] - param_values[j, k]) ^ 2
              }
            }
          }
        }
      }

      optimfn <- function(w) {
        return(crossprod(delta - X %*% w))
      }

      # TODO read up on BFGS and if it's ok to use instead of quadprog
      sol <-
        optim(
          par = rep(0, m),
          fn = optimfn,
          method = 'L-BFGS-B',
          lower = numeric(m)
        )
      # TODO check for convergence and decide what to do if not converges
      result[[metric]][[p]] <- sol$par
    }
  }
  return(result)
}

num_user_random_settings <- Sys.getenv('TSBSS_NUM_PRECOMPUTE')
if (num_user_random_settings!='') {
  num_user_random_settings <- as.numeric(num_user_random_settings)
  if (is.na(num_user_random_settings)) {
    num_user_random_settings <- 7
  }
} else {
  num_user_random_settings <- 7
}
prepare_results(lag.max, N=num_user_random_settings)
