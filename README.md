# TBSSvis

_Visual Analytics for Temporal Blind Source Separation_

This repository contains code for the prototype _TBSSvis_, a visual analytics app for the Blind Source Separation algorithm gSOBI [1, 1a]. It provides a consistent and intuitive interface to select parameters and explore components.

## Usage

Please refer to the paper:

N. Piccolotto, M. Bögl, T. Gschwandtner, C. Muehlmann, K. Nordhausen, P. Filzmoser, and S. Miksch: "TBSSvis: Visual Analytics for Temporal Blind Source Separation", submitted for publication. [https://arxiv.org/abs/2011.09896](https://arxiv.org/abs/2011.09896)

## Installation and running

Prerequisites: Node.js (>= v12), Docker (>= 19.03.13). Note that the tool itself is called **TBSS**vis but some things, e.g. environment variables, use **TSBSS** (observe the additional _S_).

1. Clone this repository
2. Install frontend dependencies: `npm install`
3. Build the backend: `docker build server --tag tsbss`
3. Run the backend with docker: `docker run -e TSBSS_DATASET=exrates -d -p 8008:8000 -v $PWD/server/app:/app tsbss` - after some preprocessing time the backend runs on port `8008` on your host, check with `docker logs` if it's working
4. Run the frontend: `npx vue-cli-service serve` - the frontend runs on port `8080` on your host

TBSSvis should now be accessible at `http://localhost:8080/` with the `exrates` [2] dataset. See next section how to change the dataset.

## Changing the dataset

Data is loaded from the subfolder `server/app/data`. Two datasets are included: `exrates` [2], a dataset of currency exchange rates, and `fetal-ecg`, a medical dataset. Note that TBSSvis expects datasets to be connected to a Gregorian calendar with resolution up to milliseconds.

To use a custom dataset, place a CSV file in the folder mentioned above. The first column must contain the date and be named `date`. The column names should be preferably short, we developed TBSSvis with 3 characters length.

Then, when starting the backend, point TBSSvis to your dataset with the `TSBSS_DATASET` environment variable. E.g., if your data is in the file `server/app/data/customdata.csv`, use  `-e TSBSS_DATASET=customdata` in the docker command in step 4 of the previous section.

## References

* [1] J. Miettinen, M. Matilainen, K. Nordhausen, and S. Taskinen, “Extracting Conditionally Heteroskedastic Components using Independent Component Analysis,” Journal of Time Series Analysis, vol. 41, no. 2, pp. 293–311, 2020, doi: 10.1111/jtsa.12505.
* [1a] https://cran.r-project.org/web/packages/tsBSS/index.html
* [2] https://cran.r-project.org/web/packages/stochvol/stochvol.pdf, see section `exrates`
