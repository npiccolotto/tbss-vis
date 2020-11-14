<template>
  <div>
    <div
      style="display:grid;grid-template-columns: repeat(2, max-content); grid-gap:15px;"
    >
      <div style="display:grid; grid-gap:10px;">
        <LagFilter
          v-on:brush="handleBrush"
          v-on:change-resolution="handleResolutionChange"
          v-bind:selectedLags="selectedLags"
          v-bind:respectMaximumLag="true"
          v-bind:lagType="lagType"
          v-bind:height="200"
          v-bind:width="1000"
        />
        <div style="height: 60px;">
          <table class="table--small">
            <thead>
              <tr>
                <td>Highlighted Lag</td>
                <td>Calendar Interval</td>
                <td>Max. Aucoorr.</td>
                <td>Autocov. Matrix Eigenvalue diff.</td>
              </tr>
            </thead>
            <tbody>
              <tr v-if="highlightedLagData">
                <td>{{ highlightedLag }}</td>
                <td>{{ highlightedLagData.calendar }}</td>
                <td>{{ highlightedLagData.autocorr }}</td>
                <td>{{ highlightedLagData.ev }}</td>
              </tr>
              <tr v-if="!highlightedLagData">
                <td>-</td>
                <td>-</td>
                <td>-</td>
                <td>-</td>
                <td>-</td>
              </tr>
            </tbody>
          </table>
        </div>
        <AutocorrelationFunction
          v-bind:width="1000"
          v-bind:height="130"
          v-bind:brushedLags="brushedLags"
          v-bind:selectedLags="selectedLags"
          v-on:select-lag="handleLagToggle"
        />
        <div>
          <SourceSelector
            v-bind:initialSource="highlightedVar"
            v-on:source-changed="handleSourceChanged"
          />
          <div
            style="display:grid;grid-template-columns: repeat(2, max-content); grid-gap:20px;"
          >
            <TimeSeries
              v-bind:margin="[10, 0, 0, 0]"
              v-bind:width="800"
              v-bind:height="50"
              v-bind:lagResolution="resolution"
              v-bind:showHighlightedLag="highlightedLag"
              v-bind:alwaysShowTimeScale="true"
              v-bind:zoom="2"
              v-bind:tsdata="[
                {
                  value: highlightedVarData,
                  color: 'black'
                }
              ]"
              v-bind:title="null"
            />
            <Scatterplot
              v-bind:width="140"
              v-bind:height="140"
              v-bind:source="highlightedVar"
              v-bind:lag="highlightedLag"
            />
          </div>
        </div>
      </div>
      <div>
        <div style="display: flex; flex-direction: column;">
          <label v-if="numLagsToSelect === 1" for="lag-direct-input"
            >Direct Lag Boundary Selection</label
          >
          <label v-else for="lag-direct-input">Direct Lag Selection</label>
          <input
            id="lag-direct-input"
            v-model="inputLags"
            type="text"
            v-bind:placeholder="numLagsToSelect === 1 ? '1950' : '1-10'"
          />
          <small v-if="numLagsToSelect === 1"
            >Format: one integer, eg. 1959</small
          >
          <small v-else>Format: 1-10,12,14</small>
          <button
            style="margin-top: 5px;"
            class="button"
            v-bind:disabled="!inputLags.length"
            v-on:click="selectLagsDirectly"
          >
            Select
          </button>
        </div>
        <div style="margin-top: 20px;">
          <strong v-if="numLagsToSelect === 1">Selected Lag Boundary</strong>
          <strong v-else>Selected Lags</strong>
          <div>
            <LagSet
              v-bind:canBin="false"
              v-bind:showLabel="1"
              v-bind:interactive="true"
              v-bind:skipEmptyBins="1"
              v-on:click-lag="removeLag"
              v-bind:values="[{ color: color(1), value: selectedLags }]"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { Vue, Component, Prop } from "vue-property-decorator";
import Scatterplot from "@/components/Scatterplot.vue";
import SourceSelector from "@/components/SourceSelector.vue";
import AutocorrelationFunction from "@/components/acf/AutocorrelationFunction.vue";
import LagFilter from "@/components/LagFilter.vue";
import range from "lodash-es/range";
import TimeSeries from "@/components/TimeSeries.vue";
import { colorLag } from "@/util/color";
import { format } from "d3-format";
import LagSet from "@/components/LagSet.vue";
import { CalendarGranule } from "../../types/api";
import { StoreState } from "../../types/store";
import pluralize from "pluralize";

class LagInputClass extends Vue {
  public source!: string;
  public lag!: number;
  public brushedLags: number[] = [];
  @Prop({ default: () => [] }) public selectedLags!: number[];
  @Prop({ type: Number, default: -1 }) public numLagsToSelect!: number;
  @Prop({ default: "" }) public lagType!: string;
  public resolution: CalendarGranule = "day";
  public inputLags: string = "";

  public highlightedVar!: string;
  public highlightedLag!: number;
  public maximumLag!: number;
}

const formatPct = format(".2%");

@Component<LagInputClass>({
  computed: {
    highlightedVar() {
      return (this.$store.state as StoreState).highlightedVar;
    },
    highlightedVarData() {
      return this.$store.state.sources.raw[this.highlightedVar];
    },
    highlightedLag() {
      return this.$store.state.highlightedLag;
    },
    maximumLag() {
      return this.$store.state.maximumLag;
    },
    highlightedLagData() {
      const state = this.$store.state as StoreState;
      let calendar = state.lag.calendar[this.resolution].find(
        l => l.lag === this.highlightedLag
      );
      if (!calendar) {
        calendar = state.lag.calendar["day"].find(
          l => l.lag === this.highlightedLag
        );
      }
      if (calendar) {
        const autocorr = state.lag.maxAutocorrelation[this.highlightedLag - 1];
        const ev = state.lag.eigenvalue[this.highlightedLag - 1];
        return {
          calendar: `${calendar.mult} ${pluralize(
            this.resolution,
            calendar.mult
          )}`,
          calendarFit: formatPct(calendar.proximity),
          autocorr,
          ev
        };
      }
    }
  },
  components: {
    Scatterplot,
    TimeSeries,
    LagSet,
    SourceSelector,
    AutocorrelationFunction,
    LagFilter
  }
})
export default class LagInput extends LagInputClass {
  handleSourceChanged(source: string) {
    this.$store.dispatch("setHighlightedVar", source);
  }

  color(lag: number) {
    return colorLag(lag, this.maximumLag);
  }

  selectLagsDirectly() {
    const input = this.inputLags as string;
    const lags = input
      .split(",")
      .map(s => s.trim())
      .flatMap(s => {
        if (/\d+-\d+/.test(s)) {
          const [l1, l2] = s.split("-").map(s => parseInt(s));
          return range(l1, l2 + 1);
        }
        return parseInt(s);
      });
    const cpy = [...this.selectedLags];
    for (const l of lags) {
      this.toggleLag(cpy, l);
    }
    this.$emit("select-lag", cpy);
    this.inputLags = "";
  }

  handleResolutionChange(resolution: CalendarGranule) {
    this.resolution = resolution;
    this.$store.dispatch("setHighlightedLag", 0);
  }

  unselectLag(lags: number[], lag: number) {
    const idx = lags.indexOf(lag);
    if (idx >= 0) {
      lags.splice(idx, 1);
    }
    lags.sort((a, b) => a - b);
  }

  selectLag(lags: number[], lag: number) {
    const idx = lags.indexOf(lag);
    if (idx === -1) {
      lags.push(lag);
    }
    lags.sort((a, b) => a - b);
  }

  removeLag({ lag }: { lag: number }) {
    const cpy = [...this.selectedLags];
    this.unselectLag(cpy, lag);
    this.$emit("select-lag", cpy);
  }

  handleLagToggle(lag: number) {
    const cpy = [...this.selectedLags];
    this.toggleLag(cpy, lag);
    this.$emit("select-lag", cpy);
  }

  toggleLag(lags: number[], lag: number) {
    if (lags.length === this.numLagsToSelect) {
      this.unselectLag(lags, lags[lags.length - 1]);
      this.selectLag(lags, lag);
    } else {
      const idx = lags.indexOf(lag);
      if (idx >= 0) {
        this.unselectLag(lags, lag);
      } else {
        this.selectLag(lags, lag);
      }
    }
  }

  handleBrush(lags: number[]) {
    this.brushedLags = lags;
  }
}
</script>

<style scoped lang="less">
.table--small {
  margin-bottom: 0;
  td {
    padding: 2px 10px;
  }
}
</style>
