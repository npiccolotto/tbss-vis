<template>
  <div>
    <div class="lag-filter__resolutions">
      <label for="day" v-show="calendar.day.length > 0"
        ><input v-model="resolution" type="radio" id="day" value="day" />
        Daily</label
      >
      <label for="week" v-show="calendar.week.length > 0"
        ><input v-model="resolution" type="radio" id="week" value="week" />
        Weekly
      </label>
      <label for="month" v-show="calendar.month.length > 0"
        ><input v-model="resolution" type="radio" id="month" value="month" />
        Monthly
      </label>
      <label for="year" v-show="calendar.year.length > 0"
        ><input v-model="resolution" type="radio" id="year" value="year" />
        Yearly
      </label>
    </div>
    <!-- dummy element for reactivity -->
    <span
      v-if="
        selectedLags.length > 0 &&
          highlightedLag &&
          maximumLag &&
          markedLags.length > 0
      "
    />
    <div
      v-bind:style="{ height: height + 'px' }"
      v-show="eigenvalue.length > 0 && autocorrelation.length > 0"
      class="parcoords"
      ref="parcoords"
    ></div>
  </div>
</template>

<script lang="ts">
import { Component, Prop, Vue, Watch } from "vue-property-decorator";
import zipWith from "lodash-es/zipWith";
import range from "lodash-es/range";
import ParCoords from "parcoord-es";
import { scaleLinear } from "d3-scale";
import { extent } from "d3-array";
import { colorLag } from "@/util/color";
import pluralize from "pluralize";
import uniq from "lodash-es/uniq";
import flatten from "lodash-es/flatten";
import { mapState } from "vuex";
import { StoreState } from "../types/store";
import { CalendarGranule, CalendarPoint } from "../types/api";

type LagDimensions = {
  lag: number;
  granule: CalendarGranule;
  mult: number;
  eigenvalue: number;
  autocorrelation: number;

  highlighted?: boolean;
};

type Brushes = Partial<Record<keyof LagDimensions, [number, number]>>;

class LagFilterClass extends Vue {
  public displayData!: LagDimensions[];
  public baseResult!: string;
  public baseResultSuccessful!: boolean;
  public chart: any = null;
  public dimensions!: Record<string, { title: string }>;
  public markedLags!: LagDimensions[];
  public highlightedLag!: number;
  public modelDiagonality!: { autocov: number[]; fourthcc: number[] };
  public modelACFDiff!: number[];
  public maximumLag!: number;
  public eigenvalue!: number[];
  public autocorrelation!: number[];
  public calendar!: Record<CalendarGranule, CalendarPoint[]>;
  @Prop({ default: 750, type: Number })
  public width!: number;
  @Prop({ default: 300, type: Number })
  public height!: number;
  @Prop({ default: () => [] }) public selectedLags!: number[];
  @Prop({ default: false }) public respectMaximumLag!: boolean;
  @Prop({ default: "" }) public lagType!: string;

  public resolution: CalendarGranule = "day";
  public brushesPerResolution: Record<CalendarGranule, Brushes> = {
    day: {},
    week: {},
    month: {},
    year: {}
  };
}

@Component<LagFilterClass>({
  computed: {
    markedLags() {
      // TODO can be faster, lots of array traversals
      const markedLags = this.selectedLags.map(l =>
        this.displayData.find(d => d.lag === l)
      );

      const highlightedLag = this.displayData.find(
        d => d.lag === this.highlightedLag
      );
      if (highlightedLag) {
        markedLags.push({ ...highlightedLag, highlighted: true });
      }

      return markedLags.filter(l => !!l);
    },
    dimensions() {
      const dimensions: Record<string, { type: string; title: string }> = {
        lag: {
          type: "number",
          title: "Lag"
        },
        mult: { type: "number", title: pluralize(this.$data.resolution) },
        autocorrelation: {
          title: "Max. Autocorrelation in Source",
          type: "number"
        },
        eigenvalue: {
          title: "Autocov. Matrix Eigenvalue Diff.",
          type: "number"
        }
      };
      if (this.baseResultSuccessful) {
        dimensions["autocov-diagonality"] = {
          title: "Autocov. Matrix Diagonality",
          type: "number"
        };
        dimensions["fourthcc-diagonality"] = {
          title: "4th Cross-Cumulant Diagonality",
          type: "number"
        };
      }
      return dimensions;
    },
    highlightedLag() {
      return this.$store.state.highlightedLag;
    },
    calendar() {
      return this.$store.state.lag.calendar;
    },
    eigenvalue() {
      return this.$store.state.lag.eigenvalue;
    },
    autocorrelation() {
      return this.$store.state.lag.maxAutocorrelation;
    },
    maximumLag() {
      return this.$store.state.maximumLag;
    },
    baseResultSuccessful() {
      if (!this.baseResult) {
        return false;
      }
      return this.$store.state.results[this.baseResult].parameters.success;
    },
    baseResult() {
      return this.$store.state.currentParameters.baseResult;
    },
    modelDiagonality() {
      if (!this.baseResultSuccessful) {
        return [];
      }
      const r = (this.$store.state as StoreState).results[this.baseResult]
        .result.model.model_diag;

      return r;
    },
    modelACFDiff() {
      if (!this.baseResultSuccessful) {
        return [];
      }
      const r = (this.$store.state as StoreState).results[this.baseResult]
        .result.model.acf_diff;

      return r;
    },
    displayData() {
      let lags = this.calendar[this.resolution] as CalendarPoint[];
      if (this.$props.respectMaximumLag) {
        lags = lags.filter(({ lag }) => lag <= this.maximumLag);
      }

      const lagNumbers = lags.map(l => l.lag);
      const ev = this.eigenvalue.filter((ev, i) => lagNumbers.includes(i + 1));
      const auto = this.autocorrelation.filter((auto, i) =>
        lagNumbers.includes(i + 1)
      );
      let result = zipWith(
        lags,
        ev,
        auto,
        (lag: CalendarPoint, ev, autocorr) => ({
          lag: lag.lag,
          granule: this.resolution,
          mult: lag.mult,
          eigenvalue: ev,
          autocorrelation: autocorr
        })
      );

      if (this.baseResultSuccessful) {
        result = result.map((r, i) => ({
          ...r,
          "autocov-diagonality": this.modelDiagonality.autocov[i],
          "fourthcc-diagonality": this.modelDiagonality.fourthcc[i]
        }));
      }

      return result;
    }
  }
})
export default class LagFilter extends LagFilterClass {
  renderParCoords() {
    if (this.displayData.length === 0) {
      return;
    }

    if (this.chart === null) {
      this.chart = ParCoords({
        markingMode: "triangle",
        triangleDistanceToAxis: (d: LagDimensions) => (d.highlighted ? 2 : 5)
      })(this.$refs.parcoords)
        .alpha(0.5)
        .width(this.$props.width)
        .height(this.$props.height)
        .data(this.displayData)
        .dimensions(this.dimensions)
        .autoscale()
        .hideAxis(["granule"])
        .reorderable()
        .color((d: LagDimensions) => colorLag(d.lag, this.maximumLag))
        //.mode("queue") // do not turn on as it leads to flashy re-renders when brushing
        .alphaOnBrushed(0.3)
        .brushMode("1D-axes")
        .on(
          "brushend",
          (data: LagDimensions[], brush: { axis: keyof LagDimensions }) => {
            this.$emit(
              "brush",
              data.map(({ lag }) => lag)
            );
          }
        );
    }

    this.chart.unmark();
    this.chart
      .data(this.displayData)
      .dimensions(this.dimensions)
      .autoscale()
      .mark(this.markedLags)
      .render();
  }

  mounted() {
    this.renderParCoords();
  }

  updated() {
    this.renderParCoords();
  }

  @Watch("resolution")
  onResolutionChanged(n: CalendarGranule, o: CalendarGranule) {
    this.$emit("change-resolution", n);
    this.$emit(
      "brush",
      this.displayData.map(({ lag }) => lag)
    );
    if (n !== o) {
      this.chart.unmark();
      this.chart
        .data(this.displayData)
        .dimensions(this.dimensions)
        .autoscale()
        .mark(this.markedLags)
        .render()
        .createAxes()
        .updateAxes();
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style lang="less">
.lag-filter__resolutions {
  display: grid;
  grid-template-columns: repeat(4, max-content);
  grid-gap: 15px;
}

.parcoords > svg,
.parcoords > canvas {
  position: absolute;
}

.parcoords > canvas {
  pointer-events: none;
}

.parcoords text.label {
  cursor: default;
  fill: black;
}

.parcoords rect.background {
  fill: transparent;
}

.parcoords rect.background:hover {
  fill: rgba(120, 120, 120, 0.2);
}

.parcoords .resize rect {
  fill: rgba(0, 0, 0, 0.1);
}

.parcoords rect.extent {
  fill: rgba(255, 255, 255, 0.25);
  stroke: rgba(0, 0, 0, 0.6);
}

.parcoords .axis line,
.parcoords .axis path {
  fill: none;
  stroke: #222;
  shape-rendering: crispEdges;
}

.parcoords canvas {
  opacity: 1;
  transition: opacity 0.3s;
}

.parcoords canvas.faded {
  opacity: 0.25;
}

.parcoords canvas.dimmed {
  opacity: 0.85;
}

.parcoords {
  -webkit-touch-callout: none;
  -webkit-user-select: none;
  -khtml-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none;
  background-color: white;
}
</style>
