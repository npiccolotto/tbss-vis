<template>
  <vue-tabs v-on:tab-change="tabChange">
    <!--<v-tab title="Overview">
      <div class="tab-content">
        <table>
          <thead>
            <tr>
              <th></th>
              <th>ID</th>
              <th>Converged?</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="id in selectedResults" v-bind:key="'w' + id">
              <td>
                <div
                  v-bind:style="{
                    background: resultColors[id],
                    width: 20 + 'px',
                    height: 20 + 'px',
                    borderRadius: '100%',
                    display: 'inline-block',
                    margin: '5px auto'
                  }"
                ></div>
              </td>
              <td>{{ id.substr(0, 6) }}</td>
              <td
                v-if="
                  $store.state.results[id] &&
                    $store.state.results[id].parameters
                "
              >
                {{ $store.state.results[id].parameters.success ? "✓" : "×" }}
              </td>
              <td>
                <button v-on:click="goToParameterInput(id)" class="small">
                  use as base
                </button>
                <button v-on:click="unselect(id)" class="small">
                  unselect
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <button v-on:click="unselectAll()">Unselect all</button>
      </div>
    </v-tab>-->
    <v-tab title="Parameters">
      <div class="tab-content">
        <!-- b values could be markers on common scale, or better to maintain the one-row-is-one-result thing multiple scales -->
        <div class="grid">
          <div style="margin-bottom:10px;">
            <strong
              >Lag Weights (b)
              <Tooltip
                v-bind:text="'0 = use only k2 lags, 1 = use only k1 lags'"
            /></strong>
            <Weight v-bind:values="bs" />
          </div>
          <div style="margin-bottom:10px;">
            <label
              ><input type="checkbox" v-model="skipEmptyBins" /> Hide empty
              bins</label
            >
          </div>
          <div style="margin-bottom:10px;">
            <strong>k1 Lags <Tooltip v-bind:text="'Lags for SOBI'"/></strong>
            <div>
              <LagSet
                v-bind:markerSize="[10, 30]"
                v-bind:values="k1s"
                v-bind:showLabel="1"
              />
            </div>
          </div>
          <div style="margin-bottom:10px;">
            <strong>k2 Lags <Tooltip v-bind:text="'Lags for vSOBI'"/></strong>
            <div>
              <LagSet
                v-bind:markerSize="[10, 30]"
                v-bind:values="k2s"
                v-bind:showLabel="1"
              />
            </div>
          </div>
        </div>
      </div>
    </v-tab>
    <v-tab title="BSS model">
      <div class="tab-content">
        <div style="margin-bottom:10px;">
          <strong>Differences in Autocov. Matrix Eigenvalues</strong>
          <p><code>sum(diff(sort(abs(eigen(M)$values))))</code></p>
          <LineChart
            v-bind:width="650"
            v-bind:height="100"
            xAxisName="Lag"
            v-bind:lcdata="scatterEigenvalues"
          />
        </div>

        <div style="margin-bottom:10px;">
          <strong>Scatter Diagonality</strong>
          <p>
            F-norm of off-diagonal elements in <code>W %*% M %*% t(W)</code>.
            Upper bars mark k1 lags, lower bars k2 lags.
          </p>
          <div
            style="display:grid; grid-template-columns: repeat(2, max-content); grid-gap: 20px;"
          >
            <div style="display:flex;">
              <label style="margin-right:5px;" for="autocov"
                ><input
                  v-model="scatterType"
                  type="radio"
                  id="autocov"
                  value="autocov"
                />
                Autocov. Matrix</label
              >
              <label for="fourthcc"
                ><input
                  v-model="scatterType"
                  type="radio"
                  id="fourthcc"
                  value="fourthcc"
                />
                4th cross-cumulant
              </label>
            </div>
            <label v-show="selectedSuccessfulResults.length > 1"
              ><input type="checkbox" v-model="superimposeDiagonality" />
              Superimpose</label
            >
          </div>
        </div>
        <div v-if="superimposeDiagonality">
          <LineChart
            v-bind:width="650"
            v-bind:height="200"
            xAxisName="Lag"
            v-bind:lcdata="superimposedDiagonality"
          />
        </div>
        <div v-else>
          <div
            v-bind:key="result"
            v-for="(d, result) in resultDiagonality"
            style="margin-bottom:20px;"
          >
            <LineChart
              v-bind:width="650"
              v-bind:height="75"
              xAxisName="Lag"
              v-bind:lcdata="[d]"
            />
          </div>
          <div
            v-bind:key="'failed' + result"
            v-for="result in selectedFailedResults"
            v-bind:style="{
              'margin-bottom': '20px',
              color: resultColors[result]
            }"
          >
            did not converge
          </div>
        </div>
      </div>
    </v-tab>
    <v-tab title="Matrix">
      <!-- W will be pxp matrices where cells are bivariate color-coded and values displayed on demand -->
      <div class="tab-content">
        <div v-if="ws.length > 1" style="margin-bottom: 10px;">
          <strong>Unmixing matrix similarity </strong>
          <p>
            Heatmap of Minimum-Distance-Index between matrices. Black means very
            similar (MD-Index: 0), white very dissimilar (MD-Index: 1).
          </p>
          <div>
            <Matrix
              v-bind:size="100"
              v-bind:matrix="wDistance"
              v-bind:margin="[0, 0, 0, 0]"
            />
          </div>
        </div>
        <div style="margin-top: 20px;">
          <strong>Unmixing matrices</strong>
          <p>
            Components are rows and sorted by interestingness. Factors are
            encoded per row from black (highest absolute value) to white
            (lowest). Click cells to display input time series and components.
          </p>
          <div
            style="margin-bottom: 10px; display:grid;grid-template-columns: repeat(2, max-content); grid-gap: 10px;"
          >
            <label for="standardized"
              ><input
                id="standardized"
                type="checkbox"
                v-model="showStandardizedW"
              />
              Scale input time series to unit variance</label
            >
          </div>
        </div>
        <div class="matrix-grid">
          <div
            style="display:flex;flex-direction:column;"
            v-for="([id, w, hue], widx) in ws"
            v-bind:key="'w' + widx"
          >
            <Matrix
              v-bind:size="200"
              v-bind:cellsInteractive="true"
              v-bind:matrix="w"
              v-bind:id="id"
              v-bind:color="hue"
              v-bind:showBorder="true"
              v-bind:rowLabels="matrixRowLabels"
              v-bind:colLabels="matrixColLabels"
              v-on:selected="handleMatrixSelection"
            />
          </div>
          <div
            style="display:flex;flex-direction:column;"
            v-for="id in selectedFailedResults"
            v-bind:key="'wfail' + id"
          >
            <div class="failed-matrix">
              <div
                class="w-marker"
                v-bind:style="{ backgroundColor: resultColors[id] }"
              ></div>
              <div style="margin-top: -5px;">did not converge</div>
            </div>
          </div>
        </div>
        <div style="margin-top: 10px;">
          <div v-for="series in inputTimeSeries" v-bind:key="series.seriesName">
            <TimeSeries
              v-bind:title="series.seriesName"
              v-bind:tsdata="[{ value: series.ts, color: 'black' }]"
            />
          </div>
          <div
            v-for="(group, result) in resultComponents"
            v-bind:key="result"
            style="margin-left: 8px;"
          >
            <TimeSeries
              v-for="series in group"
              v-bind:key="series.seriesName"
              v-bind:title="series.seriesName"
              v-bind:tsdata="[
                { value: series.ts, color: resultColors[result] }
              ]"
            />
          </div>
        </div>
      </div>
    </v-tab>

    <!-- components go here, sorted by current ranking tho -->
    <v-tab title="Components">
      <div class="tab-content">
        <ComponentComparison /></div
    ></v-tab>
  </vue-tabs>
</template>

<script lang="ts">
import { Component, Prop, Vue } from "vue-property-decorator";
import { StoreState, StoreGetters } from "../types/store";
import LineChart, { LineChartData } from "@/components/LineChart.vue";
import TimeSeries, { TSData } from "@/components/TimeSeries.vue";
import Weight from "@/components/Weight.vue";
import BarChart from "@/components/BarChart.vue";

import ComponentComparison from "@/components/ComponentComparison.vue";
import Matrix, { MatrixValue } from "@/components/Matrix.vue";
import LagSet from "@/components/LagSet.vue";
import range from "lodash-es/range";
import { newMatrix, formatInteger, sortNumbersAsc } from "@/util/util";
import { extent } from "d3-array";
import { colorDistanceMatrix } from "../util/color";
import { mapGetters } from "vuex";
import { tsIdToIndex, parseTsId, indexToTsId } from "../util/api";
import { SourcePoint } from "../types/data";
import Tooltip from "@/components/Tooltip.vue";

function union<T = any>(...sets: Set<T>[]) {
  const allElements: T[] = [];
  for (const set of sets) {
    allElements.push(...set);
  }
  return new Set<T>(allElements);
}

const DEFAULT_MATRIX_SELECTION = {
  dedupedInputs: [],
  inputs: {},
  components: {}
};

class ResultDetailClass extends Vue {
  public selectedResults!: string[];
  public selectedSuccessfulResults!: string[];
  public showStandardizedW = false;
  public scatterType: "autocov" | "fourthcc" = "autocov";

  public resultColors!: Record<string, string>;
  public tab = 0;
  public superimposeDiagonality = false;
  public resultDiagonality!: LineChartData;
  public matrixSelections: {
    dedupedInputs: number[];
    inputs: Record<string, number[]>;
    components: Record<string, number[]>;
  } = { ...DEFAULT_MATRIX_SELECTION };
}

@Component<ResultDetailClass>({
  components: {
    TimeSeries,
    BarChart,
    ComponentComparison,
    LineChart,
    Matrix,
    Tooltip,
    LagSet,
    Weight
  },
  watch: {
    selectedResults: function(n) {
      if (n.length === 0) {
        this.matrixSelections = { ...DEFAULT_MATRIX_SELECTION };
      }
    }
  },
  computed: {
    ...mapGetters([
      "resultColors",
      "selectedResults",
      "selectedFailedResults",
      "selectedSuccessfulResults"
    ]),
    skipEmptyBins: {
      get() {
        return this.$store.state.globalSkipEmptyLagBins;
      },
      set(b: boolean) {
        this.$store.dispatch("setGlobalSkipEmptyLagBins", b);
      }
    },
    showLagNumbers: {
      get() {
        return (this.$store.state as StoreState).globalShowLagNumbers;
      },
      set(show: boolean) {
        this.$store.dispatch("setGlobalShowLagNumbers", show);
      }
    },
    k1s() {
      const state = this.$store.state as StoreState;
      const k1s = this.selectedResults
        .filter(id => !!state.results[id] && !!state.results[id].parameters)
        .map(id => ({
          value: state.results[id].parameters.k1,
          b: state.results[id].parameters.b,
          color: this.resultColors[id]
        }))
        .map(r => ({ value: r.b > 0 ? r.value : [], color: r.color }));
      return k1s;
    },
    k2s() {
      const state = this.$store.state as StoreState;
      return this.selectedResults
        .filter(id => !!state.results[id] && !!state.results[id].parameters)
        .map(id => ({
          value: state.results[id].parameters.k2,
          b: state.results[id].parameters.b,
          color: this.resultColors[id]
        }))
        .map(r => ({ value: r.b < 1 ? r.value : [], color: r.color }));
    },
    bs() {
      const state = this.$store.state as StoreState;
      return this.selectedResults
        .filter(id => !!state.results[id] && state.results[id].parameters)
        .map(id => ({
          value: state.results[id].parameters.b,
          color: this.resultColors[id],
          id
        }));
    },
    scatterEigenvalues() {
      let ev = [
        {
          color: "gray",
          ticks: [[], []],
          value: (this.$store.state as StoreState).lag.eigenvalue
            .slice(0, (this.$store.state as StoreState).maximumLag)
            .map((ev, i) => ({
              x: i + 1,
              y: ev
            }))
        }
      ];
      return ev;
    },
    wDistance() {
      const wDistance = this.$store.getters.wDistances(
        this.selectedSuccessfulResults
      );
      const selectedColors = this.selectedSuccessfulResults.map(
        id => this.resultColors[id]
      );
      const additionalRowAndCol = [
        { row: "", col: "", value: 0, color: "white" },
        ...selectedColors.map((color, i) => ({
          color,
          shape: "circle",
          stroke: { color: "white", width: 5 },
          row: this.selectedSuccessfulResults[i],
          col: this.selectedSuccessfulResults[i],
          value: 0
        }))
      ];

      wDistance.splice(0, 0, additionalRowAndCol.slice(1));
      for (const [i, row] of wDistance.entries()) {
        row.splice(0, 0, additionalRowAndCol[i]);
      }

      for (const [i, row] of wDistance.entries()) {
        for (const [j, col] of row.entries()) {
          if (i > 0 && j > 0) {
            const entry = wDistance[i][j];
            entry.color = colorDistanceMatrix(1 - entry.value);
            entry.title = `MD-Index: ${entry.value}`;
          }
        }
      }

      return wDistance;
    },
    ws() {
      return (this.selectedSuccessfulResults as string[]).map(id => {
        const baseHue = this.resultColors[id];
        const wValues = newMatrix<MatrixValue>(this.$store.state.sources.p);
        if (
          !this.$store.state.results[id] ||
          !this.$store.state.results[id].result
        ) {
          return [id, wValues, baseHue];
        }

        const w = this.$store.getters.w(
          id,
          this.showStandardizedW
        ) as number[][];
        for (const [i, row] of w.entries()) {
          // body rows
          const [rowmin, rowmax] = extent(row.map(r => Math.abs(r)));
          if (rowmin === undefined || rowmax === undefined) {
            continue;
          }
          for (const [j, val] of row.entries()) {
            wValues[i][j].color = colorDistanceMatrix(
              (Math.abs(val) - rowmin) / (rowmax - rowmin)
            ).toString();
            wValues[i][j].value = val;
            wValues[i][j].title = `[${i + 1}] ${
              this.$store.state.colnames[j]
            }: ${val}`;
          }
        }
        return [id, wValues, baseHue];
      });
    },
    resultDiagonality() {
      const state = this.$store.state as StoreState;
      const results = [];
      for (const result of this.selectedSuccessfulResults) {
        if (!state.results[result] || !state.results[result].result) {
          continue;
        }
        const b = state.results[result].parameters.b;
        results.push({
          color: this.resultColors[result],
          tickBinSize: state.globalLagSetWindow,
          ticks: [
            b > 0 ? state.results[result].parameters.k1 : [],
            b < 1 ? state.results[result].parameters.k2 : []
          ],
          value: state.results[result].result.model.model_diag[
            this.scatterType
          ].map((diag, i) => ({
            x: i + 1,
            y: diag
          }))
        });
      }
      return results;
    },
    superimposedDiagonality() {
      return Object.values(this.resultDiagonality).map(d => ({
        color: d.color,
        ticks: [[], []],
        value: d.value
      }));
    },
    matrixColLabels() {
      const state = this.$store.state as StoreState;
      return state.colnames;
    },
    matrixRowLabels() {
      return range(this.$store.state.sources.p).map(i => formatInteger(i + 1));
    },
    inputTimeSeries() {
      const state = this.$store.state as StoreState;
      return this.matrixSelections.dedupedInputs.map(idx => ({
        ts: state.sources.raw[state.colnames[idx]],
        seriesName: state.colnames[idx]
      }));
    },
    resultComponents() {
      const state = this.$store.state as StoreState;
      const resultComponents = this.selectedResults
        .filter(id => state.results[id] && state.results[id].result)
        .reduce((agg, id) => {
          const rowIdxs = this.matrixSelections.components[id];
          if (!rowIdxs) {
            return { ...agg, [id]: [] };
          }
          const result = state.results[id].result;
          const f = [];
          for (const rowIdx of rowIdxs) {
            const c =
              result.sortings[state.investigatedMetric].components[rowIdx];
            const compIdx = tsIdToIndex(c.name);
            f.push({
              seriesName: formatInteger(rowIdx + 1),
              ts: result.s[compIdx]
            });
          }

          return { ...agg, [id]: f };
        }, {});
      return resultComponents;
    }
  }
})
export default class ResultDetail extends ResultDetailClass {
  tabChange(tab: number, newTab: number, oldTab: number) {
    this.tab = tab;
  }
  goToParameterInput(resultId: string) {
    this.$store.dispatch("initParameterInputWithResult", resultId);
    this.$router.push("/parameter-input");
  }
  unselect(resultId: string) {
    this.$store.dispatch("toggleSelectedResult", resultId);
  }
  unselectAll() {
    for (const res of this.$store.getters.selectedResults) {
      this.$store.dispatch("toggleSelectedResult", res);
    }
  }
  handleMatrixSelection(payload: any) {
    const { id, selection } = payload;
    type Agg = Record<"inputs" | "components", Set<number>>;
    const agg: Agg = { inputs: new Set(), components: new Set() };
    for (const [row, col] of selection) {
      agg.components.add(row);
      agg.inputs.add(col);
    }
    const otherIds = (this.$store
      .getters as StoreGetters).selectedResults.filter(res => res !== id);
    const dedupedInputs = [
      ...union(
        ...otherIds.map(id => new Set(this.matrixSelections.inputs[id])),
        agg.inputs
      )
    ];
    this.matrixSelections = {
      dedupedInputs: dedupedInputs.sort(sortNumbersAsc),
      inputs: {
        ...this.matrixSelections.inputs,
        [id]: [...agg.inputs].sort(sortNumbersAsc)
      },
      components: {
        ...this.matrixSelections.components,
        [id]: [...agg.components].sort(sortNumbersAsc)
      }
    };
  }
}
</script>

<style lang="less" scoped>
.tab-content {
  margin: 15px 0;
  width: 650px;
}

.matrix-grid {
  display: grid;
  grid-gap: 15px;
  grid-template-columns: repeat(5, 234px);
}

.w-marker {
  width: 15px;
  height: 15px;
  display: block;
  margin-left: 7.5px;

  border-radius: 100%;
}

.failed-matrix {
  display: grid;
  margin-top: 7.5px;
  grid-template-columns: 30px max-content;
}

.mixing-matrix {
  td {
    margin: 0;
    padding: 0;
    width: 10px;
    height: 10px;
    border: 0;
  }
}
</style>
