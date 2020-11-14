import {
  ACFPoint,
  CalendarGranule,
  CalendarPoint,
  ComponentSortingMetric,
  ResultEmbeddings,
  DistanceMatrix,
  ParameterEmbeddings,
  CompactMatrix,
  ComponentSimilarityMeasure
} from "./api";
import {
  SourcePoint,
  SOBIParameters,
  SOBIResult,
  Cluster,
  MedoidRank,
  TimeSeries
} from "./data";

type SelectedResult = {
  id: string;
  color: string;
};

export type HighlightTimestamp = { date: string; index: number };
export type StoreState = {
  maximumLag: number;
  resultEmbeddingConfig: {
    similarityMeasure: ComponentSimilarityMeasure;
    comparisonStrategy: "all" | "rank";
    compareRank: number;
  };
  investigatedMetric: ComponentSortingMetric;
  colorPalette: string[];
  nextColor: string;
  selectedResults: (SelectedResult | null)[];
  selectedMedoids: TimeSeries[];
  movingAverageWindow: number;
  highlightedMedoid: TimeSeries | {};
  highlightedTimestep: HighlightTimestamp | undefined;
  highlightedLag: number;
  highlightedVar: string;
  highlightedResult: string;
  highlightedTimeRange: Date[];
  highlightedLagRange: number[];
  globalShowLagNumbers: boolean;
  globalLagSetWindow: number;
  globalSkipEmptyLagBins: boolean;
  globalSemanticZoomLevel: number;
  highlightedCalendarGranule: {
    mult: number;
    granule: CalendarGranule;
  };
  lagsToCalendar: Readonly<CalendarPoint[]>;
  bestMatchingCalendarPointsPerLag: Readonly<CalendarPoint[]>;
  numInflightRequests: number;
  currentParameters: {
    baseResult: string;
    b: number;
    k1: number[];
    k2: number[];
  };
  colnames: string[];
  sources: {
    dates: Date[];
    raw: Record<string, SourcePoint[]>;
    n: number;
    p: number;
  };
  results: Record<
    string,
    {
      result: SOBIResult;
      parameters: SOBIParameters;
    }
  >;
  componentCorrelations: CompactMatrix;
  componentDistances: CompactMatrix;
  wDistances: DistanceMatrix;
  // Intra-Result clustering
  intraResultK: number;
  intraResultMedoids: Record<string, string[][]>;
  // Inter-Result clustering
  interResultK: number;
  resultClusters: Cluster[];
  clusteringGuidanceValues: (number | "NA")[];
  resultMedoidRanks: MedoidRank[];
  resultEmbeddings: ResultEmbeddings;
  parameterEmbeddings: ParameterEmbeddings;
  lag: {
    numVariablesWithAutocorrelationNotWhiteNoise: readonly number[];
    maxAutocorrelation: readonly number[];
    eigenvalue: readonly number[];
    calendar: Record<CalendarGranule, Readonly<CalendarPoint[]>>;
    // not implented
    // expectedChange: never;
    // calendar: never;
    // events: never;
    // numSamples: never;
  };
  acf: {
    raw?: Readonly<ACFPoint[]>;
    bylag?: Readonly<ACFPoint[][]>;
    byvar: Readonly<Record<string, ACFPoint[]>>;
    whitenoiseBorders: number[];
    min: number;
    max: number;
  };
};

export type StoreGetters = {
  selectedResults: string[];
  selectedSuccessfulResults: string[];
  selectedFailedResults: string[];
  resultColors: Record<string, string>;
  resultColorsInclHighlight: Record<string, string>;
  results: string[];
  lagCalendarHighlightMask: [Date, Date, 0 | 1][];
  w: (resultId: string) => number[][];
  wDistances: (results: string[]) => { value: number; color: string }[][];
  subsetComponentCorrelations: (
    set1: string[],
    set2: string[]
  ) => Record<string, Record<string, number>>;
  stat: number[];
  previousParameterValues: (
    param: keyof SOBIParameters
  ) => (string | number | number[])[];
};
