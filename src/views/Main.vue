<template>
  <main>
    <GlobalControls />
    <div
      style="display:grid;grid-gap:10px;grid-template-columns: repeat(4, max-content);"
    >
      <Folder title="TABLE"><ResultTable /></Folder>
      <Folder title="PROJECTIONS"><Results /></Folder>
      <Folder title="COMPONENT OVERVIEW">
        <div>
          <GuidedSlider
            v-bind:values="clusteringGuidance"
            v-model="k"
            v-bind:height="40"
            v-bind:width="370"
            v-bind:ticksEvery="10"
            ticksBy="value"
            :showYScale="true"
            legendValue="Amount of clusters"
            legendGuidance="Average Cluster Separation"
            legendGuidanceLow="← fewer, but bigger clusters"
            legendGuidanceHigh="more, but smaller clusters →"
          />
          <div style="display:grid;grid-gap:10px;">
            <div
              style="display:grid;grid-gap: 10px;grid-template-columns: 18px 100px max-content;"
            >
              <span />
              <span class="legend">Rank Histogram</span>
              <span class="legend">Most central component in cluster</span>
            </div>
            <div
              v-for="(medoid, midx) in medoids"
              v-bind:id="'medoid' + midx"
              v-bind:key="medoid.medoid.result_id + medoid.medoid.ts_id"
            >
              <div
                style="display:grid;grid-gap: 10px;grid-template-columns: repeat(3, max-content);"
                v-bind:data-result="medoid.medoid.result_id"
                v-bind:data-ts="medoid.medoid.ts_id"
              >
                <div v-on:click="toggleExpanded(midx)" class="toggler">
                  <font-awesome-icon
                    v-if="expandedMedoids.indexOf(midx) >= 0"
                    size="xs"
                    fixed-width
                    v-bind:icon="['far', 'eye-slash']"
                  ></font-awesome-icon>
                  <font-awesome-icon
                    v-else
                    size="xs"
                    fixed-width
                    v-bind:icon="['far', 'eye']"
                  ></font-awesome-icon>
                </div>
                <SparkHistogram
                  v-bind:height="33"
                  v-bind:width="100"
                  v-bind:cluster="medoid.medoid"
                />
                <TimeSeries
                  v-bind:title="null"
                  v-bind:tsdata="[
                    {
                      value: medoid.ts,
                      color: 'black'
                    }
                  ]"
                  v-bind:canHighlightTimestep="false"
                  v-bind:height="66"
                  v-bind:width="250"
                />
              </div>
              <div v-if="expandedMedoids.indexOf(midx) >= 0">
                <div
                  v-bind:key="rank"
                  style="margin-top: 10px;"
                  v-for="(components, rank) in medoids[midx].components"
                >
                  <div
                    v-for="(comp, cidx) in components"
                    v-bind:key="cidx"
                    v-bind:data-result="comp.time_series.result_id"
                    v-bind:data-ts="comp.time_series.ts_id"
                  >
                    <TimeSeries
                      v-bind:useSpecialLabel="
                        medoid.medoid.result_id === comp.time_series.result_id
                      "
                      v-bind:title="rank.length === 1 ? '0' + rank : rank"
                      v-bind:tsdata="[
                        {
                          value: comp.ts,
                          color:
                            resultColors[comp.time_series.result_id] || 'black'
                        }
                      ]"
                      v-bind:canHighlightTimestep="false"
                      v-bind:height="44"
                      v-bind:width="370"
                      v-bind:canClickTitle="true"
                      v-on:click="toggleResult(comp.time_series.result_id)"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div></div
      ></Folder>
      <Folder title="COMPARISON">
        <div>
          <keep-alive>
            <ResultDetail v-if="selectedResults.length > 0" />
            <div v-else>
              <div>
                Select a method in the table on the left side to open comparison
                views.
              </div>
            </div>
          </keep-alive>
        </div></Folder
      >
    </div>
  </main>
</template>

<script lang="ts">
import { Vue, Component } from "vue-property-decorator";
import Results from "@/components/Results.vue";
import TimeSeries from "@/components/TimeSeries.vue";
import GlobalControls from "@/components/GlobalControls.vue";
import GuidedSlider from "@/components/parameter-input/GuidedSlider.vue";
import ParameterInput from "@/components/parameter-input/ParameterInput.vue";
import SparkHistogram from "@/components/SparkHistogram.vue";
import ResultDetail from "@/components/ResultDetail.vue";
import ResultTable from "@/components/ResultTable.vue";
import sortBy from "lodash-es/sortBy";
import { StoreState } from "../types/store";
import Folder from "@/components/Folder.vue";
import isEqual from "lodash-es/isEqual";
import { tsIdToIndex } from "../util/api";
import debounce from "lodash-es/debounce";
import range from "lodash-es/range";
import { MedoidRank, Cluster } from "../types/data";
import filter from "lodash-es/filter";
import merge from "lodash-es/merge";
import groupBy from "lodash-es/groupBy";
import keyBy from "lodash-es/keyBy";
import { SourcePoint } from "../types/data";
import Tooltip from "@/components/Tooltip.vue";

type Combined = MedoidRank &
  Cluster & { min_rank: number; medoid_rank: number };
type DisplayMedoid = Combined & { stat: number; ts: readonly SourcePoint[] };

class MainClass extends Vue {
  public selectedResults!: string[];
  public expandedMedoids: number[] = [];
  public medoids!: DisplayMedoid[];
  public sortBy: "min_rank" | "medoid_rank" = "medoid_rank";

  toggleExpanded(medoidIndex: number) {
    const asSet = new Set(this.expandedMedoids);
    if (!asSet.has(medoidIndex)) {
      this.expandedMedoids = [...asSet, medoidIndex];
    } else {
      asSet.delete(medoidIndex);
      this.expandedMedoids = [...asSet];
    }
  }

  toggleResult(resultId: string) {
    this.$store.dispatch("toggleSelectedResult", resultId);
  }
}

@Component<MainClass>({
  components: {
    Results,
    Folder,
    SparkHistogram,
    Tooltip,
    TimeSeries,
    ParameterInput,
    ResultTable,
    ResultDetail,
    GuidedSlider,
    GlobalControls
  },
  watch: {
    highlightedMedoid: function(n: TimeSeries, o) {
      if (n !== o) {
        const idx = this.medoids.findIndex(m => isEqual(m.medoid, n));

        this.toggleExpanded(idx);
        const node = document.querySelector(`#medoid${idx}`);
        if (node) {
          node.scrollIntoView({ behavior: "smooth", block: "center" });
        }
      }
    }
  },
  computed: {
    highlightedMedoid() {
      return this.$store.state.highlightedMedoid;
    },
    k: {
      set(n) {
        this.$store.dispatch("setInterResultK", n);
      },
      get() {
        return (this.$store.state as StoreState).interResultK;
      }
    },
    clusteringGuidance() {
      const state = this.$store.state as StoreState;
      return state.clusteringGuidanceValues.map((v, i) => ({
        guidanceValue: v === "NA" ? null : v,
        value: i + state.sources.p
      }));
    },
    selectedResults() {
      return this.$store.getters.selectedResults;
    },
    resultColors() {
      return this.$store.getters.resultColors;
    },
    medoids() {
      const state = this.$store.state as StoreState;
      const store = this.$store;

      const allMedoidsCombined: Combined[] = [];
      let allMedoidsGrouped = groupBy(
        [...state.resultClusters, ...state.resultMedoidRanks].filter(
          cm =>
            state.results[cm.medoid.result_id] &&
            state.results[cm.medoid.result_id].parameters &&
            state.results[cm.medoid.result_id].parameters.success &&
            state.results[cm.medoid.result_id].result
        ),
        m => `${m.medoid.result_id}#${m.medoid.ts_id}`
      );
      for (const [key, arr] of Object.entries(allMedoidsGrouped)) {
        const combinedObj: Combined = merge({} as Combined, ...arr);
        combinedObj.min_rank = Math.min(
          ...combinedObj.components.map(c => c.rank)
        );
        combinedObj.medoid_rank = combinedObj.components.find(
          o => `${o.time_series.result_id}#${o.time_series.ts_id}` === key
        )!.rank;
        allMedoidsCombined.push(combinedObj);
      }
      allMedoidsCombined.sort((a, b) => a[this.sortBy] - b[this.sortBy]);
      return allMedoidsCombined.map(medoid => {
        const r = state.results[medoid.medoid.result_id];
        const components = medoid.components
          .filter(
            comp =>
              state.results[comp.time_series.result_id] &&
              state.results[comp.time_series.result_id].result
          )
          .map(comp => ({
            ...comp,
            ts:
              state.results[comp.time_series.result_id].result.s[
                tsIdToIndex(comp.time_series.ts_id)
              ]
          }));
        const groupedComponents = groupBy(
          sortBy(components, ["rank", "dist_to_medoid"]),
          "rank"
        );
        return {
          ...medoid,
          components: groupedComponents,
          stat: store.getters.doi(medoid.medoid),
          ts: r.result.s[tsIdToIndex(medoid.medoid.ts_id)]
        };
      });
    }
  }
})
export default class Main extends MainClass {}
</script>

<style lang="less" scoped>
.toggler {
  cursor: pointer;
  user-select: none;
  display: flex;
  align-items: center;
}
.legend {
  font-size: 10px;
  color: gray;
}
</style>
