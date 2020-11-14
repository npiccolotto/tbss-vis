import { ComponentSortings } from "./api";

// Should mirror types in api.d.ts except those that don't need transform

export type SourcePoint = {
  value: number;
  date: string;
  parsedDate: Date;
};

export type SOBIParameters = {
  id: string;
  k1: number[];
  k2: number[];
  b: number;
  eps: number;
  success: boolean;
  maxiter: number;
};

type SOBIMixingMatrix = number[][];

export type ModelFit = {
  model_diag: {
    autocov: number[];
    fourthcc: number[];
  };
  acf_diff: number[];
};

export type SOBIResult = {
  id: string;
  w: SOBIMixingMatrix;
  w_std: SOBIMixingMatrix;
  s: Readonly<SourcePoint[]>[];
  model: ModelFit;
  sortings: ComponentSortings;
};

export type TimeSeries = {
  result_id: string;
  ts_id: string;
};

export type Cluster = {
  medoid: TimeSeries;
  components: { time_series: TimeSeries; dist_to_medoid: number }[];
};

export type MedoidRank = {
  medoid: TimeSeries;
  components: { time_series: TimeSeries; rank: number }[];
};
