<template>
  <div class="global-controls">
    <div v-show="!firstScreen">
      <button v-on:click="goToParamInput">New parametrization</button>
    </div>
    <div v-show="!firstScreen" style="display:flex;flex-direction:column;">
      <div class="input-label">
        Interestingness function
        <Tooltip
          v-bind:size="'md'"
          v-bind:text="'Components are sorted by the value of this function.'"
        />
      </div>
      <select
        style="max-width: 150px;"
        class="small"
        v-model="investigatedMetric"
      >
        <option disabled value="">Please select a function</option>
        <option
          v-bind:key="metric"
          v-bind:value="metric"
          v-for="metric in metrics"
          >{{ metricLabels[metric] }}</option
        >
      </select>
    </div>
    <div v-show="!firstScreen" style="display:flex;flex-direction:column;">
      <div class="input-label" style="display: flex;">
        <label
          >Lagset bin size: {{ globalLagSetWindow.lag }} /
          {{ globalLagSetWindow.mult }}
          {{ globalLagSetWindow.granule }}
          <Tooltip
            v-bind:size="'md'"
            v-bind:text="'Lag sets are aggregated into bins of this size.'"
        /></label>
      </div>
      <div style="display:flex;">
        <input
          style="max-width: 100px;"
          v-model.number="lagSetWindow.mult"
          type="number"
          class="small"
          min="1"
        />

        <select
          style="max-width: 100px;"
          class="small"
          v-model="lagSetWindow.granule"
        >
          <option disabled value="">Select a calendar unit</option>
          <option v-bind:key="granule" v-for="granule in granules">{{
            granule
          }}</option>
        </select>
      </div>
    </div>
    <div v-show="!firstScreen">
      <div class="input-label">
        Selection Order
        <Tooltip
          v-bind:size="'md'"
          v-bind:text="'Drag and drop colors to change the result order.'"
        />
      </div>
      <div class="flex-child">
        <draggable v-model="colorPalette">
          <div
            v-for="(r, i) in colorPalette"
            :key="r.id"
            :title="r.color !== r.id ? r.id.substring(0, 6) : ''"
            v-bind:style="{
              width: '10px',
              marginLeft: i === colorPalette.length - 1 ? '5px' : '0px',
              height: '10px',
              background: r.color === r.id ? 'white' : r.color,
              border: '5px solid ' + r.color
            }"
          ></div>
        </draggable>
      </div>
    </div>
    <div style="display:flex;flex-direction:column;">
      <div class="input-label">
        Time Series Y resolution level:
        {{ $store.state.globalSemanticZoomLevel + 1 }}
      </div>
      <input
        v-model.number.lazy="$store.state.globalSemanticZoomLevel"
        type="range"
        class="small"
        v-bind:min="0"
        v-bind:max="3"
      />
    </div>

    <div>
      <div class="input-label">Visible time range</div>
      <div>
        {{ visibleTimeRange }}
        <button
          v-show="timeRangeBrushed"
          class="small"
          v-on:click="resetTimeBrush"
        >
          reset
        </button>
      </div>
    </div>

    <!--
    <div style="display:flex;flex-direction:column;">
      <div class="input-label">Highlight every n-th calendar granule</div>
      <div>
        <input
          v-model.number="$store.state.highlightedCalendarGranule.mult"
          type="number"
          class="small"
          min="0"
        />

        <select
          class="small"
          v-model="$store.state.highlightedCalendarGranule.granule"
        >
          <option disabled value="">Please select a calendar granule</option>
          <option v-bind:key="granule" v-for="granule in granules">{{
            granule
          }}</option>
        </select>
      </div>
    </div>-->
  </div>
</template>

<script lang="ts">
import { Vue, Prop, Component } from "vue-property-decorator";
import { CalendarPoint } from "../types/api";
import pluralize from "pluralize";
import { StoreState } from "../types/store";
import isEqual from "lodash-es/isEqual";
import { format } from "date-fns";
import { resultColorPalette } from "../util/color";
import Tooltip from "@/components/Tooltip.vue";

class GlobalControlsClass extends Vue {
  @Prop({ default: false }) public firstScreen!: boolean;
  public globalLagSetWindow!: number;
  public investigatedMetric!: string;
}

@Component<GlobalControlsClass>({
  components: { Tooltip },
  watch: {
    lagSetWindow: {
      deep: true,
      handler: function(n) {
        const newWindow = this.$store.getters.lagForCalendarPoint(n);
        this.$store.dispatch("setGlobalLagSetWindow", newWindow);
      }
    }
  },
  computed: {
    colorPalette: {
      get() {
        const state = this.$store.state as StoreState;
        const s = [];
        for (const c of state.colorPalette) {
          const usedIndex = state.selectedResults.findIndex(
            r => r !== null && r.color === c
          );
          if (usedIndex >= 0) {
            s.push(state.selectedResults[usedIndex]);
          } else {
            s.push({
              id: c,
              color: c
            });
          }
        }
        return s;
      },
      set(colorPalette: { color: string; id: string }[]) {
        this.$store.dispatch(
          "setColorPalette",
          colorPalette.map(c => c.color)
        );
        this.$store.dispatch(
          "setSelectedResults",
          colorPalette.filter(c => c.id !== c.color)
        );
      }
    },
    resultColorPalette: function() {
      const state = this.$store.state as StoreState;
      const result = resultColorPalette.map((color, i) => ({
        color,
        i,
        usedBy: state.selectedResults[i]
      }));
      return result;
    },
    timeRangeBrushed: function() {
      const state = this.$store.state as StoreState;
      return state.highlightedTimeRange.length < state.sources.n;
    },
    visibleTimeRange: function() {
      const df = "yyyy-MM-dd";
      const start = this.$store.state.highlightedTimeRange[0];
      const end = this.$store.state.highlightedTimeRange[
        this.$store.state.highlightedTimeRange.length - 1
      ];
      return `${format(start, df)} to ${format(end, df)}`;
    },
    globalLagSetWindow: function() {
      return this.$store.getters.exactCalendarPointForLag(
        this.$store.state.globalLagSetWindow,
        this.$data.lagSetWindow.granule
      );
    },
    investigatedMetric: {
      get() {
        return this.$store.state.investigatedMetric;
      },
      set(n) {
        this.$store.dispatch("setInvestigatedMetric", n);
      }
    }
  },
  data: function() {
    return {
      metrics: ["skewness", "kurtosis", "periodicity"],
      metricLabels: {
        skewness: "Abs. Skewness",
        kurtosis: "Kurtosis",
        periodicity: "Periodicity"
      },
      granules: ["day", "week", "month", "year"],
      lagSetWindow: {
        mult: 1,
        granule: "day"
      }
    };
  }
})
export default class GlobalControls extends GlobalControlsClass {
  goToParamInput() {
    this.$router.push("/parameter-input");
  }
  resetTimeBrush() {
    this.$store.dispatch("setHighlightedTimeRange", null);
  }
  untoggleResult(paletteItem: any) {
    if (paletteItem.usedBy) {
      const resultId = paletteItem.usedBy;
      this.$store.dispatch("toggleSelectedResult", resultId);
    }
  }
}
</script>

<style lang="less" scoped>
.global-controls {
  border-bottom: 1px solid lightgray;
  margin-bottom: 10px;
  padding-bottom: 10px;
  display: grid;
  grid-template-columns: repeat(6, max-content);
  grid-gap: 15px;
  align-items: center;
}
.flex-child > * {
  display: flex;
}
</style>
