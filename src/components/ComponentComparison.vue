<template>
  <div>
    <div
      style="display: grid; grid-template-columns: max-content max-content; grid-gap: 20px; margin-bottom: 10px;"
    >
      <div v-show="selectedSuccessfulResults.length > 1 && k == 1">
        <label for="comparisonmode">
          <input id="comparisonmode" type="checkbox" v-model="superimpose" />
          Superimpose columns
        </label>
      </div>
      <div v-show="selectedSuccessfulResults.length > 1 && !superimpose">
        <label for="slope">
          <input id="slope" type="checkbox" v-model="showSlope" />
          Show correlation slope
        </label>
      </div>
    </div>
    <div class="superimposed" v-if="superimpose">
      <div
        v-for="(g, cidx) in superimposedComponents"
        v-bind:key="'superimposed' + cidx"
      >
        <div style="display:flex;">
          <div
            class="doi-bar"
            v-bind:title="'Euclidean distance: ' + formatNumber(g.sumDists)"
            v-bind:style="{ width: sumDistWidth + 'px' }"
          >
            <div
              v-bind:style="{
                height: 5 + 'px',
                width: sumDistScale(g.sumDists) + 'px',
                background: '#666'
              }"
            ></div>
          </div>
          <TimeSeries
            v-bind:title="g.seriesName"
            v-bind:height="50"
            v-bind:width="600"
            v-bind:tsdata="g.ts"
          />
        </div>
      </div>
    </div>
    <div
      v-else
      v-bind:class="{
        'component-grid': true,
        'component-grid--show-slope': showSlope
      }"
    >
      <div v-for="(thing, thingidx) in renderStructure" v-bind:key="thingidx">
        <div v-if="thing.type === 'components'">
          <div
            v-for="comp in thing.data"
            v-bind:key="comp.seriesName"
            v-bind:data-comp="comp.seriesName"
            style="display:flex;"
          >
            <div
              class="doi-bar"
              v-bind:title="'Interestingness: ' + formatNumber(comp.doi)"
              v-bind:style="{ width: doiBarWidth + 'px' }"
            >
              <div
                v-bind:style="{
                  height: 5 + 'px',
                  width: doiBarScale[thing.resultId](comp.doi) + 'px',
                  background: resultColors[thing.resultId]
                }"
              ></div>
            </div>

            <TimeSeries
              v-bind:id="comp.seriesName"
              v-bind:title="formatComponentRank(comp.doiIndex)"
              v-bind:height="50"
              v-bind:width="200"
              v-bind:tsdata="[comp.ts]"
              v-on:click="handleClick(comp.seriesName)"
              v-on:updated-height="updatedHeight"
              v-on:reset-zoom="resetHeight(thing.resultId, comp.seriesName)"
              v-on:increased-zoom="
                increaseHeight(thing.resultId, comp.seriesName)
              "
              v-bind:canClickTitle="true"
            />
          </div>
        </div>
        <div v-else>
          <SlopeGraph
            v-if="showSlope"
            v-bind:heights="thing.data.heights"
            v-bind:elements="thing.data.elements"
            v-bind:values="thing.data.correlations"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { Component, Prop, Vue } from "vue-property-decorator";
import { StoreState, StoreGetters } from "../types/store";
import { mapGetters } from "vuex";
import { tsIdToIndex, parseTsId } from "../util/api";
import range from "lodash-es/range";
import { format } from "d3-format";
import { scaleLinear, ScaleLinear } from "d3-scale";
import TimeSeries, { TSData } from "@/components/TimeSeries.vue";
import SlopeGraph from "@/components/SlopeGraph.vue";
import { formatInteger } from "../util/util";

type Component = {
  ts: TSData;
  doiIndex: number;
  doi: number;
  seriesName: string;
};
type ComponentSet = Component[];
type RenderStructure = (
  | { type: "components"; resultId: string; data: ComponentSet }
  | {
      type: "correlations";
      resultId: string;
      data: {
        correlations: Record<string, Record<string, number>>;
        heights: Record<string, number>;
        elements: [string[][], string[][]];
      };
    }
)[];

class ComponentComparisonClass extends Vue {
  public selectedSuccessfulResults!: string[];
  public sumComponentDistances!: (a: string[]) => number;
  public tsZoomLevels: Record<string, Record<string, number>> = {};
  public tsHeights!: Record<string, number>;

  public resultColors!: Record<string, string>;
  public components!: Record<string, ComponentSet>;
  public superimposedComponents!: {
    sumDists: number;
    ts: TSData[];
  }[];
  public k!: number;
  public showSlope = false;
  public doiBarWidth = 20;
  public sumDistWidth = 50;
  public superimpose = false;
  public correlations!: Record<string, Record<string, Record<string, number>>>;
}

const TS_HEIGHTS = [25, 50, 100, 200];

@Component<ComponentComparisonClass>({
  components: {
    TimeSeries,
    SlopeGraph
  },
  computed: {
    ...mapGetters([
      "resultColors",
      "selectedSuccessfulResults",
      "sumComponentDistances"
    ]),
    k: {
      get() {
        return (this.$store.state as StoreState).intraResultK;
      },
      set(newK: number) {
        this.$store.dispatch("setIntraResultK", newK);
      }
    },
    tsHeights() {
      const heights: Record<string, number> = {};

      for (const id of this.selectedSuccessfulResults) {
        if (!this.tsZoomLevels[id]) {
          continue;
        }
        for (const [i, comp] of this.components[id].entries()) {
          heights[comp.seriesName] = this.tsZoomLevels[id][comp.seriesName];
        }
      }
      return heights;
    },
    formatNumber() {
      return format(",.4f");
    },
    sumDistScale() {
      const allSumDists = this.superimposedComponents.map(c => c.sumDists);

      return scaleLinear()
        .domain([0, Math.max(...allSumDists)])
        .range([1, this.sumDistWidth]);
    },
    doiBarScale() {
      const state = this.$store.state as StoreState;
      const scales: Record<string, ScaleLinear<number, number>> = {};
      for (const id of this.selectedSuccessfulResults) {
        if (!state.results[id]) {
          continue;
        }
        const dois =
          state.results[id].result.sortings[state.investigatedMetric].vector;
        scales[id] = scaleLinear()
          .domain([Math.min(...dois), Math.max(...dois)])
          .range([1, this.doiBarWidth]);
      }
      return scales;
    },
    superimposedComponents() {
      const state = this.$store.state as StoreState;
      if (this.k > 1) {
        return [];
      }
      const components: ComponentSet[] = range(state.sources.p).map(() => []);
      for (const [resultId, group] of Object.entries(this.components)) {
        for (let i = 0; i < group.length; i++) {
          components[i].push(group[i]);
        }
      }
      const groupedComponents = [];
      for (const [i, group] of components.entries()) {
        const sumDists = this.sumComponentDistances(
          group.map(g => g.seriesName)
        );
        groupedComponents.push({
          sumDists,
          seriesName: formatInteger(i + 1),
          ts: group.map(g => g.ts)
        });
      }
      return groupedComponents;
    },
    correlations() {
      const r: Record<string, Record<string, Record<string, number>>> = {};

      let i = 0;
      while (i + 1 < this.selectedSuccessfulResults.length) {
        const result1 = this.selectedSuccessfulResults[i];
        const result2 = this.selectedSuccessfulResults[i + 1];
        const comps1 = this.components[result1].map(c => c.seriesName).flat();
        const comps2 = this.components[result2].map(c => c.seriesName).flat();
        const corrs = (this.$store
          .getters as StoreGetters).subsetComponentCorrelations(comps1, comps2);
        r[result2] = corrs;
        i += 1;
      }
      return r;
    },
    renderStructure() {
      const result: RenderStructure = [];
      for (const [i, resultId] of this.selectedSuccessfulResults.entries()) {
        if (i === 0) {
          result.push({
            type: "components",
            resultId,
            data: this.components[resultId]
          });
        } else {
          const lastResultId = this.selectedSuccessfulResults[i - 1];
          if (this.showSlope) {
            result.push({
              type: "correlations",
              resultId,
              data: {
                correlations: this.correlations[resultId],
                heights: this.tsHeights,
                elements: [
                  [this.components[lastResultId].map(c => c.seriesName)],
                  [this.components[resultId].map(c => c.seriesName)]
                ]
              }
            });
          }
          result.push({
            type: "components",
            resultId,
            data: this.components[resultId]
          });
        }
      }
      return result;
    },
    components() {
      const state = this.$store.state as StoreState;
      const metric = state.investigatedMetric;
      const k = state.intraResultK;

      const rest: number[] = [];
      const components: Record<string, ComponentSet> = {};
      for (const id of this.selectedSuccessfulResults) {
        if (!state.results[id] || !state.results[id].result) {
          continue;
        }
        components[id] = [];
        const timeSeriesInResult = state.results[id].result.sortings[
          metric
        ].components.map(c => c.name);
        const s = state.results[id].result.s;
        for (const seriesName of timeSeriesInResult) {
          // seriesName is "abcdedf#Series 5"
          // seriesIndex is 5
          const seriesIndex = tsIdToIndex(seriesName);
          // Then we collect the DOI value for Series 5
          const doiIndex = state.results[id].result.sortings[
            metric
          ].components.findIndex(r => r.name === seriesName)!;
          const doi =
            state.results[id].result.sortings[metric].components[doiIndex]
              .value;
          components[id].push({
            doi,
            seriesName,
            doiIndex,
            ts: {
              color: this.resultColors[id],
              value: s[seriesIndex]
            }
          });
        }
      }
      for (const id of Object.keys(components)) {
        components[id].sort((c1, c2) => c2.doi - c1.doi);
      }
      return components;
    }
  }
})
export default class ComponentComparison extends ComponentComparisonClass {
  mounted() {
    this.k = 1;
  }
  formatComponentRank(x: number) {
    const rank = x + 1;
    return rank > 9 ? `${rank}` : `0${rank}`;
  }
  handleClick(seriesName: string) {
    //this.$store.dispatch("scrollToComponentCluster", seriesName);
    this.$store.dispatch("flipComponent", seriesName);
  }
  updatedHeight(eventData: { id: string; computedHeight: number }) {
    const { id, computedHeight } = eventData;
    const { result_id } = parseTsId(id);
    if (!this.tsZoomLevels[result_id]) {
      Vue.set(this.tsZoomLevels, result_id, {});
    }
    Vue.set(this.tsZoomLevels[result_id], id, computedHeight);
  }
  increaseHeight(result: string, component: string) {
    const currentZoom = this.tsZoomLevels[result][component] || 0;
    Vue.set(this.tsZoomLevels[result], component, currentZoom + 1);
  }
  resetHeight(result: string, component: string) {
    Vue.set(this.tsZoomLevels[result], component, 0);
  }
}
</script>

<style lang="less" scoped>
.superimposed {
  width: 610px;
}
.component-grid {
  width: 610px;
  display: grid;
  grid-gap: 15px;
  grid-template-columns: repeat(5, 250px);

  &--show-slope {
    grid-template-columns: 250px 50px 250px 50px 250px 50px 250px 50px 250px;
  }
}
.doi-bar {
  margin-right: 3px;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: flex-end;
}
</style>
