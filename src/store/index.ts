import {
  ACFPoint,
  CalendarGranule,
  CalendarPoint,
  EigenvaluePoint,
  SOBIResult,
  SOBIResultPoint,
  SourcePoint as APISourcePoint,
  SOBIParameters,
  ComponentSortings,
  ResultEmbeddings,
  DistanceMatrix,
  ModelFit as APIModelFit,
  MedoidRankBoxed,
  ComponentSortingMetric,
  ClusterBoxed,
  ParameterEmbeddings,
  Boxed,
  GuidanceInitialValuesBoxed,
  CompactMatrix,
  ComponentSimilarityMeasure
} from "@/types/api";
import {
  SourcePoint,
  SOBIMixingMatrix,
  Cluster,
  MedoidRank,
  ModelFit,
  TimeSeries
} from "@/types/data";
import {
  HighlightTimestamp,
  StoreState,
  StoreGetters,
  SelectedResult
} from "@/types/store";
import _axios from "axios";
import { parse, isBefore, isAfter, isEqual } from "date-fns";
import { getDay, getISOWeek, getMonth, getYear } from "date-fns";
import group from "lodash-es/groupBy";
import range from "lodash-es/range";
import Vue from "vue";
import Vuex, { ActionContext } from "vuex";
import { newMatrix } from "@/util/util";
import { tsIdToIndex, unboxObject, unbox, parseTsId } from "@/util/api";
import { resultColorPalette } from "@/util/color";
import _isEqual from "lodash-es/isEqual";
import { extent, histogram } from "d3-array";

function lcomb2<T>(array: T[]): [T, T][] {
  const k = 2;
  const combs = [];
  for (let i = 0; i < array.length; i++) {
    for (let j = i + 1; j < array.length; j++) {
      combs.push([array[i], array[j]] as [T, T]);
    }
  }
  return combs;
}

function trackedAsyncAction<T = any>(
  fn: (ctx: ActionContext<StoreState, StoreState>, payload: T) => void
) {
  return async function(
    ctx: ActionContext<StoreState, StoreState>,
    payload: T
  ) {
    ctx.dispatch("incInflightRequests");
    try {
      await fn.call(null, ctx, payload);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
    } finally {
      ctx.dispatch("decInflightRequests");
    }
  };
}

Vue.use(Vuex);
const axios = _axios.create({
  baseURL: process.env.VUE_APP_API_URL,
  timeout: 15 * 60_000,
  responseType: "json"
});

function getWhitenoiseBorders(n: number) {
  const border = 2 / Math.sqrt(n);
  return [-border, border];
}

function assignRunningNumber(arr: number[]) {
  const result = [];
  let runningNumber = 0;
  for (let i = 0; i < arr.length; i++) {
    const el = arr[i];
    const prev = i > 0 ? arr[i - 1] : el;
    if (el !== prev) {
      runningNumber += 1;
    }
    result.push(runningNumber);
  }
  return result;
}

const DEFAULT_PARAMS = {
  b: 0.9,
  k1: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  k2: [1, 2, 3],
  baseResult: ""
};

export default new Vuex.Store<StoreState>({
  state: {
    maximumLag: -1,
    resultEmbeddingConfig: {
      compareRank: 0,
      comparisonStrategy: "all",
      similarityMeasure: "shape" as ComponentSimilarityMeasure
    },
    movingAverageWindow: 5,
    investigatedMetric: "kurtosis" as ComponentSortingMetric,
    intraResultK: 0,
    interResultK: 0,
    wDistances: [],
    highlightedLag: 0,
    highlightedMedoid: {},
    highlightedVar: "",
    highlightedResult: "",
    highlightedTimeRange: [],
    highlightedLagRange: [],
    highlightedTimestep: undefined,
    globalShowLagNumbers: true,
    globalSemanticZoomLevel: 0,
    globalSkipEmptyLagBins: true,
    globalLagSetWindow: 1,
    componentCorrelations: { rownames: [], data: [] },
    componentDistances: { rownames: [], data: [] },
    colorPalette: resultColorPalette,
    nextColor: resultColorPalette[0],
    selectedResults: [],
    selectedMedoids: [],
    highlightedCalendarGranule: {
      mult: 0,
      granule: "month" as CalendarGranule
    },
    numInflightRequests: 0,
    colnames: [],
    currentParameters: { ...DEFAULT_PARAMS },
    results: {},
    resultClusters: [],
    intraResultMedoids: {},
    clusteringGuidanceValues: [],
    resultMedoidRanks: [],
    parameterEmbeddings: {
      k1: { embedding: [], distances: [], scale: 0 },
      k2: { embedding: [], distances: [], scale: 0 }
    },
    resultEmbeddings: {
      embedding: [],
      distances: [],
      scale: 0
    },
    sources: {
      dates: [],
      raw: {},
      n: 0,
      p: 0
    },
    lagsToCalendar: [],
    bestMatchingCalendarPointsPerLag: [],
    lag: {
      numVariablesWithAutocorrelationNotWhiteNoise: [],
      maxAutocorrelation: [],
      eigenvalue: [],
      calendar: {
        day: [],
        week: [],
        month: [],
        year: []
      }
    },
    acf: {
      whitenoiseBorders: [0, 0],
      min: 1,
      max: 0,
      byvar: {}
    }
  },
  getters: {
    initialized: (state: StoreState) => {
      return (
        state.sources.dates.length > 0 &&
        state.maximumLag > 0 &&
        state.lagsToCalendar.length > 0
      );
    },
    lagForCalendarPoint: (state: StoreState) => (
      desiredPoint: CalendarPoint
    ) => {
      if (desiredPoint.granule === "day") {
        return desiredPoint.mult;
      }
      const points = state.lagsToCalendar.filter(
        point =>
          point.mult === desiredPoint.mult &&
          point.granule === desiredPoint.granule
      );
      const proxs = points.map(p => p.proximity);
      const max = Math.max(...proxs);
      return points[proxs.findIndex(prox => prox === max)].lag;
    },
    resultColors: (state: StoreState, getters: StoreGetters) => {
      const resultColors: Record<string, string> = {};

      for (const id of getters.results) {
        let c = "black";
        if (getters.selectedResults.includes(id)) {
          c = state.selectedResults.find(r => r !== null && r.id === id)!.color;
        }
        resultColors[id] = c;
      }

      return resultColors;
    },
    resultColorsInclHighlight: (state: StoreState, getters: StoreGetters) => {
      const resultColors: Record<string, string> = { ...getters.resultColors };
      if (
        state.highlightedResult &&
        resultColors[state.highlightedResult] === "black"
      ) {
        resultColors[state.highlightedResult] = state.nextColor;
      }
      return resultColors;
    },
    maxParamBinValue: (state: StoreState) => (
      id: string,
      binSize: number = 10
    ) => {
      let max = 0;
      for (const param of ["k1", "k2"]) {
        const wasUsed =
          (param === "k1" && state.results[id].parameters.b > 0) ||
          (param === "k2" && state.results[id].parameters.b < 1);
        if (!wasUsed) {
          continue;
        }
        const lags = state.results[id].parameters[param as "k1" | "k2"];
        const thresholds = range(Math.round(state.maximumLag / binSize)).map(
          t => t * binSize
        );
        const h = histogram()
          .domain([1, state.maximumLag])
          .thresholds(thresholds);
        const bins = h(lags);
        const maxVal = Math.max(...bins.map(b => b.length));
        if (maxVal > max) {
          max = maxVal;
        }
      }
      return max;
    },
    exactCalendarPointForLag: (state: StoreState) => (
      lag: number,
      desiredGranule: CalendarGranule = "day"
    ) => {
      if (desiredGranule === "day") {
        return { lag, mult: lag, granule: "day", proximity: 1 };
      }
      const points = state.lagsToCalendar.filter(
        point => point.lag === lag && point.granule === desiredGranule
      );
      const proxs = points.map(p => p.proximity);
      const max = Math.max(...proxs);
      return points[proxs.findIndex(prox => prox === max)];
    },
    results: (state: StoreState) => {
      const results: [string, number][] = Object.keys(state.results)
        .filter(r => state.results[r] && state.results[r].parameters)
        .map(r => [r, state.results[r].parameters.b]);
      results.sort((a, b) => a[1] - b[1]);
      return results.map(r => r[0]);
    },
    selectedResults: (state: StoreState) => {
      return state.selectedResults
        .filter(x => x !== null)
        .map(r => r!!.id)
        .filter(id => state.results[id] && state.results[id].parameters);
    },
    selectedResultsAndColor: (state: StoreState) => {
      return state.selectedResults.filter(x => x !== null);
    },
    selectedSuccessfulResults: (state: StoreState) => {
      return state.selectedResults
        .filter(
          r =>
            r !== null &&
            !!state.results[r.id] &&
            !!state.results[r.id].parameters
        )
        .filter(
          r => state.results[r!!.id] && state.results[r!!.id].parameters.success
        )
        .map(r => r!!.id);
    },
    selectedFailedResults: (state: StoreState) => {
      return state.selectedResults
        .filter(
          r =>
            r !== null &&
            !!state.results[r!!.id] &&
            !!state.results[r!!.id].parameters
        )
        .filter(r => !state.results[r!!.id].parameters.success)
        .map(r => r!!.id);
    },
    w: (state: StoreState) => (resultId: string, standardized: boolean) => {
      const basicW = standardized
        ? state.results[resultId].result.w_std
        : state.results[resultId].result.w;
      const currentSort =
        state.results[resultId].result.sortings[state.investigatedMetric]
          .components;
      const currentIndices = currentSort.map(com => tsIdToIndex(com.name));
      const w: number[][] = [];
      for (const idx of currentIndices) {
        w.push(basicW[idx]);
      }
      return w;
    },
    subsetComponentCorrelations: (state: StoreState) => (
      set1: string[],
      set2: string[]
    ) => {
      const idxs1 = set1.map(c =>
        state.componentCorrelations.rownames.indexOf(c)
      );
      const idxs2 = set2.map(c =>
        state.componentCorrelations.rownames.indexOf(c)
      );

      const result: Record<string, Record<string, number>> = {};
      for (const [i, row] of state.componentCorrelations.data.entries()) {
        if (idxs1.indexOf(i) >= 0) {
          const c1Name = set1[idxs1.indexOf(i)];
          if (!result[c1Name]) {
            result[c1Name] = {};
          }
          for (const [j, col] of row.entries()) {
            if (idxs2.indexOf(j) >= 0) {
              const c2Name = set2[idxs2.indexOf(j)];
              result[c1Name][c2Name] = col;
            }
          }
        }
      }
      return result;
    },
    sumComponentDistances: (state: StoreState) => (components: string[]) => {
      const combs = lcomb2(components);
      let sum = 0;
      for (const [a, b] of combs) {
        const ai = state.componentDistances.rownames.indexOf(a);
        const bi = state.componentDistances.rownames.indexOf(b);
        sum += state.componentDistances.data[ai][bi];
      }
      return sum;
    },
    wDistances: (state: StoreState) => (results: string[]) => {
      const wDistances = state.wDistances;
      const ret = newMatrix<{
        value: number;
        color: string;
      }>(results.length);
      for (const [i, row] of results.entries()) {
        for (const [j, col] of results.entries()) {
          const distanceRow = wDistances.find(r => r._row === row);
          if (distanceRow) {
            ret[i][j] = {
              value: distanceRow[col],
              color: ""
            };
          }
        }
      }
      return ret;
    },
    doi: (state: StoreState) => (t: TimeSeries) => {
      const metric = state.investigatedMetric;
      const { result_id, ts_id } = t;
      const r = state.results[result_id];
      if (!r) {
        return 0;
      }
      return r.result.sortings[metric].components[tsIdToIndex(ts_id)].value;
    },
    previousParameterValues: (state: StoreState) => (
      parameter: keyof SOBIParameters
    ) => {
      return Object.keys(state.results).map(
        id => state.results[id].parameters[parameter]
      );
    },
    lagCalendarHighlightMask: (state: StoreState) => {
      const m = state.highlightedCalendarGranule.mult;
      const g = state.highlightedCalendarGranule.granule;

      if (m < 1) {
        return [];
      }

      let dates = state.sources.dates;
      const fn = {
        day: getDay,
        week: getISOWeek,
        month: getMonth,
        year: getYear
      }[g];
      const calendarValues = dates.map(d => fn(d));
      const bitmask = assignRunningNumber(calendarValues).map(cs =>
        cs % m === 0 ? 1 : 0
      );
      type DateBit = {
        bit: 0 | 1;
        date: Date;
      };
      const bitmaskWithDates: DateBit[] = bitmask.map((b, i) => ({
        bit: b,
        date: dates[i]
      }));
      // Aggregate bit mask as to not render 6K color steps in every time series
      const result = [] as [Date, Date, 0 | 1][];
      let prev: DateBit = bitmaskWithDates[0];
      for (const b of bitmaskWithDates) {
        if (prev.bit !== b.bit) {
          result.push([prev.date, b.date, prev.bit] as [Date, Date, 0 | 1]);
          prev = b;
        }
      }
      const last = bitmaskWithDates[bitmaskWithDates.length - 1];
      if (!isEqual(last.date, prev.date)) {
        result.push([prev.date, last.date, prev.bit]);
      }
      return result;
    }
  },

  mutations: {
    flipComponent(state: StoreState, seriesName: string) {
      const { result_id, ts_id } = parseTsId(seriesName);
      const ts_idx = tsIdToIndex(ts_id);
      Vue.set(
        state.results[result_id].result.s,
        ts_idx,
        Object.freeze(
          state.results[result_id].result.s[ts_idx].map(p => ({
            ...p,
            value: -p.value
          }))
        )
      );
    },
    setHighlightedMedoid(state: StoreState, medoid: TimeSeries) {
      state.highlightedMedoid = medoid;
    },
    setIntraResultK(state: StoreState, k: number) {
      state.intraResultK = k;
    },
    setInterResultK(state: StoreState, k: number) {
      state.interResultK = k;
    },
    setIntraResultMedoids(state: StoreState, medoids) {
      state.intraResultMedoids = medoids;
    },
    setGlobalShowLagNumbers(state: StoreState, show: boolean) {
      state.globalShowLagNumbers = show;
    },
    setHighlightedTimestep(state: StoreState, ts: HighlightTimestamp) {
      state.highlightedTimestep = ts;
    },
    setColumnNames(state: StoreState, colnames: string[]) {
      state.colnames = colnames;
      Vue.set(state.sources, "p", state.colnames.length);
      state.intraResultK = state.colnames.length;
    },
    setColumn(
      state: StoreState,
      { colname, data }: { colname: string; data: APISourcePoint[] }
    ) {
      let transformedData = [] as SourcePoint[];

      if (state.sources.dates.length === 0) {
        // no dates were parsed so far
        const now = new Date();
        transformedData = data.map((srcp, i) => ({
          date: srcp.date,
          value: parseFloat(srcp.value),
          parsedDate: parse(srcp.date, "yyyy/MM/dd", now)
        }));
        const parsedDates = transformedData.map(x => x.parsedDate);

        Vue.set(state.sources, "dates", Object.freeze(parsedDates));
        state.highlightedTimeRange = parsedDates;
      } else {
        transformedData = data.map((srcp, i) => ({
          date: srcp.date,
          value: parseFloat(srcp.value),
          parsedDate: state.sources.dates[i]
        }));
      }

      Vue.set(state.sources.raw, colname, Object.freeze(transformedData));
      Vue.set(state.sources, "n", transformedData.length);
      Vue.set(
        state.acf,
        "whitenoiseBorders",
        getWhitenoiseBorders(transformedData.length)
      );
      state.lag.calendar = {
        ...state.lag.calendar,
        day: Object.freeze(
          transformedData.map((d, i) => ({
            granule: "day",
            mult: i + 1,
            lag: i + 1,
            proximity: 1
          }))
        )
      };
    },
    setAutocorrelation(state: StoreState, data: ACFPoint[]) {
      const byvar = group(data, "variable");
      let bylag = Object.entries(group(data, "lag"))
        .map(([lag, points]) => [parseInt(lag), points] as [number, ACFPoint[]])
        .sort(([l1], [l2]) => l1 - l2)
        .map(([, v]) => v);
      // TODO rename to inverseWhiteNoiseSimilarity
      const numVariablesWithAutocorrelationNotWhiteNoise = bylag.map(
        acfPoints =>
          acfPoints.filter(
            v =>
              v.value < state.acf.whitenoiseBorders[0] ||
              v.value > state.acf.whitenoiseBorders[1]
          ).length / acfPoints.length
      );
      const maxAutocorrelation = bylag.map(acfPoints =>
        Math.max(...acfPoints.map(point => Math.abs(point.value)))
      );
      const [min, max]: [number, number] = data.reduce(
        ([min, max], point) => [
          Math.min(min, point.value),
          Math.max(max, point.value)
        ],
        [1, 0]
      );
      state.acf = {
        ...state.acf,
        raw: Object.freeze(data),
        min,
        max,
        byvar: Object.freeze(byvar),
        bylag: Object.freeze(bylag)
      };
      state.lag = {
        ...state.lag,
        maxAutocorrelation: Object.freeze(maxAutocorrelation),
        numVariablesWithAutocorrelationNotWhiteNoise: Object.freeze(
          numVariablesWithAutocorrelationNotWhiteNoise
        )
      };
    },
    setMaximumLag(state: StoreState, lag: number) {
      state.maximumLag = lag;
      state.highlightedLagRange = range(0, lag + 1);
    },
    setEigenvalue(state: StoreState, eigenvalues: EigenvaluePoint[]) {
      state.lag = {
        ...state.lag,
        eigenvalue: Object.freeze(eigenvalues.map(ev => parseFloat(ev.value)))
      };
    },
    setCalendarProximities(
      state: StoreState,
      proximities: Record<CalendarGranule, CalendarPoint[]>
    ) {
      Vue.set(state.lag, "calendar", { ...state.lag.calendar, ...proximities });
    },
    setHighlightedLag(state: StoreState, lag: number) {
      state.highlightedLag = lag;
    },
    setHighlightedResult(state: StoreState, result: string) {
      state.highlightedResult = result;
    },
    setHighlightedVar(state: StoreState, variable: string) {
      state.highlightedVar = variable;
    },
    setGlobalLagSetWindow(state: StoreState, window: number) {
      state.globalLagSetWindow = window;
    },
    setGlobalSkipEmptyLagBins(state: StoreState, skip: boolean) {
      state.globalSkipEmptyLagBins = skip;
    },
    resetCurrentParameters(state) {
      state.currentParameters = { ...DEFAULT_PARAMS };
    },
    setCurrentParameter(
      state: StoreState,
      { variable, value }: { variable: string; value: any }
    ) {
      Vue.set(state.currentParameters, variable, value);
    },
    initParameterInputWithResult(state: StoreState, id: string) {
      let usedParams = state.results[id].parameters;
      state.currentParameters.baseResult = id;
      state.currentParameters.b = usedParams.b;
      state.currentParameters.k1 = usedParams.k1;
      state.currentParameters.k2 = usedParams.k2;
    },
    incInflightRequests(state: StoreState) {
      state.numInflightRequests += 1;
    },
    decInflightRequests(state: StoreState) {
      state.numInflightRequests -= 1;
    },
    addResultParameterData(state: StoreState, parameters: SOBIParameters) {
      const id = unbox(parameters.id);
      const existingData = (state.results && state.results[id]) || {
        parameters: {}
      };
      const newData = {
        ...existingData,
        parameters: {
          ...existingData.parameters,
          ...parameters,
          id,
          b: unbox(parameters.b),
          eps: unbox(parameters.eps),
          maxiter: unbox(parameters.maxiter),
          success: unbox(parameters.success)
        }
      };
      const newResults = { ...state.results, [id]: newData };
      state.results = newResults;
    },
    addResultComponentData(state: StoreState, r: SOBIResult) {
      const s: SourcePoint[][] = Object.keys(r.s[0])
        .filter(k => !k.startsWith("_"))
        .sort((a, b) => {
          const ai = tsIdToIndex(a);
          const bi = tsIdToIndex(b);
          return ai - bi;
        })
        .map(k =>
          r.s.map((d, i) => ({
            value: d[k],
            date: d._row,
            parsedDate: state.sources.dates[i]
          }))
        );
      const model: ModelFit = {
        model_diag: {
          autocov: r.model.model_diag.autocov.map(d => unbox(d)),
          fourthcc: r.model.model_diag.fourthcc.map(d => unbox(d))
        },
        acf_diff: r.model.acf_diff
      };
      Vue.set(state, "results", {
        ...state.results,
        [r.id]: {
          ...state.results[r.id],
          result: {
            ...r,
            model,
            s: s.map(row => Object.freeze(row))
          }
        }
      });
    },
    setLagsToCalendar(state: StoreState, lagsAndCalendar: CalendarPoint[]) {
      state.lagsToCalendar = Object.freeze(lagsAndCalendar);
      // this takes ages on large datasets
      /* const bestApproxMatches = range(1, state.maximumLag + 1).map(lag => {
        let closest = state.lagsToCalendar[0];
        for (const current of state.lagsToCalendar) {
          const currentDiff = Math.abs(current.lag - lag);
          const closestDiff = Math.abs(closest.lag - lag);
          if (currentDiff < closestDiff) {
            closest = current;
          }
          if (currentDiff === closestDiff) {
            if (current.proximity > closest.proximity) {
              closest = current;
            } else {
              return closest;
            }
          }
        }
        return closest;
      });
      state.bestMatchingCalendarPointsPerLag = Object.freeze(bestApproxMatches);*/
    },
    setBestMatchingLagsToCalendar(
      state: StoreState,
      lagsAndPoints: CalendarPoint[]
    ) {
      state.bestMatchingCalendarPointsPerLag = Object.freeze(lagsAndPoints);
    },
    setResultEmbeddings(state: StoreState, embeddings: ResultEmbeddings) {
      state.resultEmbeddings = embeddings;
    },
    setParameterEmbeddings(state: StoreState, embeddings: ParameterEmbeddings) {
      state.parameterEmbeddings = embeddings;
    },
    setDistanceMatrix(state: StoreState, distances: DistanceMatrix) {
      state.wDistances = distances;
    },
    setClusters(state: StoreState, clusters: Cluster[]) {
      state.resultClusters = clusters;
    },
    setMedoidRanks(state: StoreState, ranks: MedoidRank[]) {
      state.resultMedoidRanks = ranks;
    },
    setClusteringGuidance(state: StoreState, guidanceData: number[]) {
      state.clusteringGuidanceValues = guidanceData;
    },
    setInvestigatedMetric(state: StoreState, metric: ComponentSortingMetric) {
      state.investigatedMetric = metric;
    },
    setHighlightedLagRange(
      state: StoreState,
      r: { start: number; end: number } | null
    ) {
      if (r === null) {
        state.highlightedLagRange = range(0, state.maximumLag + 1);
      } else {
        let { start, end } = { ...r };
        start = Math.round(start);
        end = Math.round(end);
        start = Math.max(1, start);
        state.highlightedLagRange = range(start - 1, end + 1);
      }
    },
    setHighlightedTimeRange(
      state: StoreState,
      range: { start: Date; end: Date } | null
    ) {
      if (range === null) {
        state.highlightedTimeRange = state.sources.dates;
      } else {
        const { start, end } = range;

        // TODO since they're sorted i can search from left and right separately
        state.highlightedTimeRange = state.sources.dates.filter(
          d =>
            isEqual(d, start) ||
            (isAfter(d, start) && (isEqual(d, end) || isBefore(d, end)))
        );
      }
    },
    setColorPalette(state: StoreState, colorPalette: string[]) {
      state.colorPalette = colorPalette;
      let nextColor = "black";
      const usedColors = state.selectedResults.map(c => c && c.color);
      for (const c of state.colorPalette) {
        if (!usedColors.includes(c)) {
          nextColor = c;
          break;
        }
      }
      state.nextColor = nextColor;
    },
    setSelectedResults(state: StoreState, results: SelectedResult[]) {
      state.selectedResults = results;
    },
    toggleSelectedResult(state: StoreState, resultId: string) {
      const idx = state.selectedResults.findIndex(
        s => s !== null && s.id === resultId
      );
      if (idx >= 0) {
        // toggle off
        Vue.set(state.selectedResults, idx, null);
      } else {
        // assign first free index or append
        const firstNullIdx = state.selectedResults.indexOf(null);
        if (firstNullIdx >= 0) {
          Vue.set(state.selectedResults, firstNullIdx, {
            id: resultId,
            color: state.nextColor
          });
        } else {
          if (state.selectedResults.length === 4) {
            // max length reached, nothing happens because there aren't any colors left
            // and dropping a selected result seems bad
          } else {
            state.selectedResults = [
              ...state.selectedResults,
              { id: resultId, color: state.nextColor }
            ];
          }
        }
      }
      const usedColors = state.selectedResults.map(c => c && c.color);
      let nextColor = "black";
      for (const c of state.colorPalette) {
        if (!usedColors.includes(c)) {
          nextColor = c;
          break;
        }
      }
      state.nextColor = nextColor;
    },
    setResultEmbeddingConfig(state: StoreState, payload) {
      state.resultEmbeddingConfig = {
        ...state.resultEmbeddingConfig,
        ...payload
      };
    },
    setComponentCorrelations(state: StoreState, corrs: CompactMatrix) {
      state.componentCorrelations = Object.freeze(corrs);
    },
    setComponentDistances(state: StoreState, dists: CompactMatrix) {
      state.componentDistances = Object.freeze(dists); // This should still update when object is exchanged, TODO check
    }
  },
  actions: {
    // SYNC ACTIONS
    scrollToComponentCluster({ commit, state }, seriesName: string) {
      const ids = parseTsId(seriesName);
      const cluster = state.resultClusters.find(c =>
        c.components.some(comp => _isEqual(comp.time_series, ids))
      )!;
      commit("setHighlightedMedoid", cluster.medoid);
    },
    setIntraResultK({ commit, dispatch }, k: number) {
      commit("setIntraResultK", k);
      dispatch("fetchIntraResultMedoids");
    },
    setInterResultK({ commit, dispatch }, k: number) {
      commit("setInterResultK", k);
      dispatch("fetchClusters");
    },
    setGlobalShowLagNumbers({ commit }, show: boolean) {
      commit("setGlobalShowLagNumbers", show);
    },
    setMaximumLag({ commit }, lag: number) {
      commit("setMaximumLag", lag);
    },
    highlightTimestep({ commit }, ts: HighlightTimestamp) {
      commit("setHighlightedTimestep", ts);
    },
    setHighlightedLag({ commit }, lag: number) {
      commit("setHighlightedLag", lag);
    },
    setHighlightedResult({ commit }, result: string) {
      commit("setHighlightedResult", result);
    },
    setHighlightedVar({ commit }, variable: string) {
      commit("setHighlightedVar", variable);
    },
    resetCurrentParameters({ commit }) {
      commit("resetCurrentParameters");
    },
    setCurrentParameter(
      { commit },
      { variable, value }: { variable: string; value: any }
    ) {
      commit("setCurrentParameter", { variable, value });
    },
    setLagsToCalendar({ commit }, lagsAndCalendar: CalendarPoint[]) {
      commit("setLagsToCalendar", lagsAndCalendar);
    },
    initParameterInputWithResult({ commit }, id: string) {
      commit("initParameterInputWithResult", id);
    },
    incInflightRequests({ commit }) {
      commit("incInflightRequests");
    },
    decInflightRequests({ commit }) {
      commit("decInflightRequests");
    },
    setResultEmbeddings({ commit }, embeddings: ResultEmbeddings) {
      commit("setResultEmbeddings", embeddings);
    },
    setParameterEmbeddings({ commit }, embeddings) {
      commit("setParameterEmbeddings", embeddings);
    },
    setDistanceMatrix({ commit }, distances: DistanceMatrix) {
      commit("setDistanceMatrix", distances);
    },
    setClusters({ commit }, clusters: Cluster[]) {
      commit("setClusters", clusters);
    },
    setMedoidRanks({ commit }, ranks) {
      commit("setMedoidRanks", ranks);
    },
    setClusteringGuidance({ commit }, guidancedata: number[]) {
      commit("setClusteringGuidance", guidancedata);
    },
    setGlobalLagSetWindow({ commit, dispatch }, window: number) {
      commit("setGlobalLagSetWindow", window);
      dispatch("fetchParameterEmbeddings");
    },
    setGlobalSkipEmptyLagBins({ commit }, skip: boolean) {
      commit("setGlobalSkipEmptyLagBins", skip);
    },
    setInvestigatedMetric(
      { commit, dispatch, state },
      metric: ComponentSortingMetric
    ) {
      commit("setInvestigatedMetric", metric);
      dispatch("fetchMedoidRanks");
      dispatch("fetchResultEmbeddings");
    },
    setHighlightedTimeRange({ commit }, payload) {
      commit("setHighlightedTimeRange", payload);
    },
    setHighlightedLagRange({ commit }, payload) {
      commit("setHighlightedLagRange", payload);
    },
    toggleSelectedResult({ commit, dispatch }, resultId: string) {
      commit("toggleSelectedResult", resultId);
      dispatch("fetchIntraResultMedoids");
    },
    setColorPalette({ commit }, colors) {
      commit("setColorPalette", colors);
    },
    setSelectedResults({ commit }, results) {
      commit("setSelectedResults", results);
    },
    setResultEmbeddingConfig({ commit, dispatch }, payload) {
      commit("setResultEmbeddingConfig", payload);
      dispatch("fetchResultEmbeddings");
    },
    // ASYNC ACTIONS
    // TODO error handling? what happens in axios on error status codes?
    applyMaximumLag: trackedAsyncAction<number>(async function applyMaximumLag(
      { commit },
      lag
    ) {
      const resp = await axios.post(`/guidance`, { lag });
      commit("setMaximumLag", lag);
    }),
    flipComponent: trackedAsyncAction(async function flipComponent(
      { commit, dispatch },
      seriesName: string
    ) {
      await axios.post("/invert", { seriesName });
      commit("flipComponent", seriesName);
      dispatch("fetchComponentDistances");
      dispatch("fetchComponentCorrelations");
    }),
    fetchColumnNames: trackedAsyncAction(async function fetchColumnNames({
      commit
    }) {
      const resp = await axios.get("/data/metadata/colnames");
      commit("setColumnNames", resp.data);
    }),
    fetchColumn: trackedAsyncAction<string>(async function fetchColumn(
      { commit },
      colname
    ) {
      const resp = await axios.get<APISourcePoint[]>(`/data/column/${colname}`);
      commit("setColumn", {
        colname,
        data: resp.data
      });
    }),
    fetchEigenvalueGuidance: trackedAsyncAction(
      async function fetchEigenvalueGuidance({ commit }) {
        const resp = await axios.get<EigenvaluePoint[]>(
          "/guidance/autocov-eigenvalue"
        );
        commit("setEigenvalue", resp.data);
      }
    ),
    fetchAutocorrelationGuidance: trackedAsyncAction(
      async function fetchAutocorrelationGuidance({ commit }) {
        const resp = await axios.get<ACFPoint[]>("/guidance/acf");
        commit("setAutocorrelation", resp.data);
      }
    ),
    fetchLagsToCalendar: trackedAsyncAction<CalendarPoint[]>(
      async function fetchLagsToCalendar({ commit }) {
        const lagsToCalendar = await axios.get<CalendarPoint[]>(
          `/guidance/calendar-granule`
        );
        commit("setLagsToCalendar", lagsToCalendar.data);
      }
    ),
    fetchInitialGuidanceValues: trackedAsyncAction(
      async function fetchInitialGuidanceValues({ commit }) {
        const resp = await axios.get<GuidanceInitialValuesBoxed>("/guidance");
        commit("setMaximumLag", unbox(resp.data.lag));
        commit("setHighlightedVar", unbox(resp.data.col));
      }
    ),
    fetchCalendarProximities: trackedAsyncAction(
      async function fetchCalendarProximities({ commit }) {
        const week = await axios.get<ACFPoint[]>(
          "/guidance/calendar?granule=week"
        );
        const month = await axios.get<ACFPoint[]>(
          "/guidance/calendar?granule=month"
        );
        const year = await axios.get<ACFPoint[]>(
          "/guidance/calendar?granule=year"
        );
        commit("setCalendarProximities", {
          week: week.data,
          month: month.data,
          year: year.data
        });
      }
    ),
    submitCurrentParameters: trackedAsyncAction(
      async function submitCurrentParameters({ state, dispatch }) {
        const resp = await axios.post<Boxed<string>>("/gsobi", {
          k1: state.currentParameters.k1.join(","),
          k2: state.currentParameters.k2.join(","),
          b: state.currentParameters.b
        });
        const resultId = unbox(resp.data);
        dispatch("fetchResult", resultId);
        dispatch("fetchResultComparisonData");
        dispatch("toggleSelectedResult", resultId);
        dispatch("resetCurrentParameters");
      }
    ),
    fetchParameterEmbeddings: trackedAsyncAction<ParameterEmbeddings>(
      async function fetchParameterEmbeddings({ commit, state }) {
        const parameterEmbeddings = await axios.get<ParameterEmbeddings>(
          `/gsobi/parameter-embeddings`,
          {
            params: {
              lagbinsize: state.globalLagSetWindow
            }
          }
        );
        commit("setParameterEmbeddings", parameterEmbeddings.data);
      }
    ),
    fetchResultEmbeddings: trackedAsyncAction<ResultEmbeddings>(
      async function fetchResultEmbeddings({ commit, state }) {
        const resultEmbeddings = await axios.get<ResultEmbeddings>(
          `/gsobi/result-embeddings`,
          {
            params: {
              sort_by: state.investigatedMetric,
              similarity: state.resultEmbeddingConfig.similarityMeasure,
              compare_rank: state.resultEmbeddingConfig.compareRank,
              comparison_strategy:
                state.resultEmbeddingConfig.comparisonStrategy
            }
          }
        );
        commit("setResultEmbeddings", resultEmbeddings.data);
      }
    ),
    fetchMatrixDistances: trackedAsyncAction<DistanceMatrix>(
      async function fetchMatrixDistances({ commit }) {
        const d = await axios.get<DistanceMatrix>(`/gsobi/w-hat-distances`);
        commit("setDistanceMatrix", d.data);
      }
    ),
    fetchIntraResultMedoids: trackedAsyncAction<Record<string, string[]>>(
      async function fetchIntraResultMedoids({ commit, getters, state }) {
        const clusters = await axios.get("/gsobi/components/intra-medoids", {
          params: {
            k: state.intraResultK,
            result_ids: getters.selectedResults.join(",")
          }
        });
        commit("setIntraResultMedoids", clusters.data);
      }
    ),
    fetchClusters: trackedAsyncAction<number>(async function fetchClusters({
      commit,
      dispatch,
      state
    }) {
      const clusters = await axios.get<ClusterBoxed[]>(
        `/gsobi/components/inter-medoids`,
        { params: { k: state.interResultK } }
      );
      commit(
        "setClusters",
        clusters.data.map(cluster => ({
          ...cluster,
          medoid: unboxObject(cluster.medoid),
          components: cluster.components.map(comp => unboxObject(comp))
        }))
      );
      commit("setInterResultK", clusters.data.length);
      dispatch("fetchClusteringGuidance");
      dispatch("fetchMedoidRanks");
    }),
    fetchClusteringGuidance: trackedAsyncAction<number[]>(
      async function fetchClusteringGuidance({ commit }) {
        const guidance = await axios.get<number[]>("/guidance/clustering");
        commit("setClusteringGuidance", guidance.data);
      }
    ),
    fetchMedoidRanks: trackedAsyncAction<MedoidRankBoxed[]>(
      async function fetchMedoidRanks({ state, commit }) {
        const ranks = await axios.get<MedoidRankBoxed[]>(
          `/gsobi/components/ranks/${state.investigatedMetric}`
        );
        commit(
          "setMedoidRanks",
          ranks.data.map(r => ({
            medoid: unboxObject(r.medoid),
            components: r.components.map(comp => unboxObject(comp))
          }))
        );
      }
    ),
    fetchResult: trackedAsyncAction<string>(async function fetchResult(
      { commit, state },
      id
    ) {
      if (
        state.results[id] &&
        state.results[id].result &&
        state.results[id].result.s
      ) {
        return;
      }
      const w = await axios.get<{
        W: SOBIMixingMatrix;
        W_std: SOBIMixingMatrix;
      }>(`/gsobi/${id}/w`);
      const s = await axios.get<SOBIResultPoint[]>(`/gsobi/${id}/s`);
      const model = await axios.get<APIModelFit>(`/gsobi/${id}/model`);
      const sortings = await axios.get<ComponentSortings>(
        `/gsobi/${id}/sortings`
      );
      commit("addResultComponentData", {
        w: w.data.W,
        w_std: w.data.W_std,
        s: s.data,
        id,
        model: model.data,
        sortings: sortings.data
      });
    }),
    fetchResults: trackedAsyncAction<void>(async function fetchResults({
      dispatch,
      commit
    }) {
      const results = await axios.get<Record<string, SOBIParameters>>("/gsobi");
      for (const id of Object.keys(results.data)) {
        commit("addResultParameterData", { ...results.data[id], id: [id] });
        if (unbox(results.data[id].success)) {
          dispatch("fetchResult", id);
        }
      }
    }),
    fetchComponentCorrelations: trackedAsyncAction<CompactMatrix>(
      async function fetchComponentCorrelations({ commit }) {
        const correlations = await axios.get<CompactMatrix>(
          "/gsobi/component-correlations"
        );
        commit("setComponentCorrelations", correlations.data);
      }
    ),
    fetchComponentDistances: trackedAsyncAction<CompactMatrix>(
      async function fetchComponentDistances({ commit }) {
        const distances = await axios.get<CompactMatrix>(
          "/gsobi/component-distances"
        );
        commit("setComponentDistances", distances.data);
      }
    ),
    async fetchResultComparisonData({ dispatch }) {
      dispatch("fetchResultEmbeddings");
      dispatch("fetchParameterEmbeddings");
      dispatch("fetchMatrixDistances");
      dispatch("fetchClusters");
      dispatch("fetchClusteringGuidance");
      dispatch("fetchMedoidRanks");
      dispatch("fetchComponentDistances");
      dispatch("fetchComponentCorrelations");
    },
    async fetchInitialData({ state, dispatch }) {
      await dispatch("fetchInitialGuidanceValues");
      await dispatch("fetchLagsToCalendar");
      dispatch("fetchAutocorrelationGuidance");
      dispatch("fetchEigenvalueGuidance");
      dispatch("fetchCalendarProximities");
      await dispatch("fetchColumnNames");
      for (const colname of state.colnames) {
        dispatch("fetchColumn", colname);
      }
    },
    async resetMaximumLag({ dispatch }) {
      const metadata = await axios.get<[number, number]>("/data/metadata/size");
      const [nrow] = metadata.data;
      const maxLag = nrow - Math.floor(nrow / 4);
      await axios.post(`/guidance`, null, {
        params: { lag: maxLag }
      });
      window.location.reload();
    }
  },
  modules: {}
});
