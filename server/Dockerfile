FROM rstudio/plumber:latest
LABEL maintainer="Nikolaus Piccolotto <nikolaus.piccolotto@tuwien.ac.at>"

RUN apt-get update -qq && apt-get install -y

RUN R -e "install.packages('stochvol')"
RUN R -e "install.packages('zoo')"
RUN R -e "install.packages('reshape2')"
RUN R -e "install.packages('moments')"
RUN R -e "install.packages('tsBSS')"
RUN R -e "install.packages('JADE')"
RUN R -e "install.packages('digest')"
RUN R -e "install.packages('hash')"
RUN R -e "install.packages('tidyverse')"
RUN R -e "install.packages('MASS')"
RUN R -e "install.packages('cluster')"
RUN R -e "install.packages('philentropy')"
RUN R -e "install.packages('lhs')"
RUN R -e "install.packages('tictoc')"
RUN R -e "install.packages('pryr')"

CMD ["/app/api.R"]

