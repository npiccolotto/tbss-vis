import { SOBIMixingMatrix } from "./data";

export type ACFPoint = {
  lag: number;
  variable: string;
  value: number;
};

export type SourcePoint = {
  value: string;
  date: string;
};

export type EigenvaluePoint = { lag: number; value: string };

export type CalendarGranule =
  | "month"
  | "week"
  | "year"
  | "day"
  | "hour"
  | "minute"
  | "second"
  | "millisecond";
export type CalendarPoint = {
  lag: number;
  mult: number;
  granule: CalendarGranule;
  proximity: number;
};

export type ComponentSortingMetric = "kurtosis" | "skewness" | "periodicity";
export type ComponentSimilarityMeasure = "doi" | "dist";

export type CompactMatrix = {
  rownames: string[];
  data: number[][];
};

type DistanceMatrixRow = Record<string, number> & { _row: string };
export type DistanceMatrix = DistanceMatrixRow[];
export type EmbeddingPoint = {
  x: number;
  y: number;
  _row: string;
  //original mds coordinates
  ox: number;
  oy: number;
};
export type EmbeddingWithDistance = {
  embedding: EmbeddingPoint[];
  scale: number; // largest original coordinate / map edge length
  distances: DistanceMatrix;
};
export type ResultEmbeddings = EmbeddingWithDistance;
export type ParameterEmbeddings = Record<"k1" | "k2", EmbeddingWithDistance>;

export type ComponentSortings = Record<
  ComponentSortingMetric,
  {
    vector: number[];
    components: { name: string; value: number }[];
  }
>;

export type ModelFit = {
  model_diag: {
    autocov: [number][];
    fourthcc: [number][];
  };
  acf_diff: number[];
};

export type SOBIResultPoint = Record<string, number> & { _row: string };
export type SOBIResult = {
  id: string;
  w: SOBIMixingMatrix;
  w_std: SOBIMixingMatrix;
  s: SOBIResultPoint[];
  model: ModelFit;
  sortings: ComponentSortings;
};

export type Boxed<T> = [T];

export type SOBIParameters = {
  id: Boxed<string>;
  k1: number[];
  k2: number[];
  b: Boxed<number>;
  maxiter: Boxed<number>;
  eps: Boxed<number>;
  success: Boxed<boolean>;
};

export type TimeSeriesBoxed = {
  result_id: Boxed<string>;
  ts_id: Boxed<string>;
};

export type ClusterBoxed = {
  medoid: TimeSeriesBoxed;
  components: {
    time_series: TimeSeriesBoxed;
    dist_to_medoid: Boxed<number>;
  }[];
};

export type MedoidRankBoxed = {
  medoid: TimeSeriesBoxed;
  parameter_histograms: {
    k1: number[];
    k2: number[];
    b: number[];
  };
  results_in_cluster: string[];
  components: { time_series: TimeSeriesBoxed; rank: Boxed<number> }[];
};

export type GuidanceInitialValuesBoxed = {
  lag: Boxed<number>;
  col: Boxed<string>;
};
