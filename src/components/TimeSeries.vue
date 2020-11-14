<template>
  <div class="time-series">
    <span
      v-on:click="handleClick"
      v-bind:class="{
        'time-series__title': true,
        'time-series__title--clickable': canClickTitle,
        'time-series__title--special': useSpecialLabel
      }"
      >{{ title }}</span
    >
    <svg
      v-bind:width="width + margin[1] + margin[3]"
      v-bind:height="computedHeight + margin[0] + margin[2]"
    >
      <g v-bind:transform="'translate(' + margin[3] + ',' + margin[0] + ')'">
        <linearGradient id="timeseries-gradient">
          <stop
            v-bind:key="index"
            v-for="(colorstop, index) in colorstops"
            v-bind:offset="colorstop.offset"
            v-bind:stop-color="colorstop.color"
          />
        </linearGradient>
        <rect
          fill="url(#timeseries-gradient)"
          class="time-series__highlight-lag"
          x="0"
          y="0"
          v-bind:width="width"
          v-bind:height="computedHeight"
        />
        <path
          class="time-series__line"
          v-for="(series, sidx) in tsdata"
          v-bind:key="sidx"
          v-bind:d="paths[sidx]"
          v-bind:stroke="series.color"
        />
        <g transform="translate(0,-7)" v-if="showHighlightedLag > 0">
          <line
            class="time-series__highlight-lag"
            v-bind:stroke="highlightedLag.color"
            v-bind:x1="0"
            v-bind:y1="0"
            v-bind:x2="highlightedLag.length"
            v-bind:y2="0"
          />
          <g
            v-bind:transform="
              'translate(' + (highlightedLag.length + 5) + ',2)'
            "
          >
            <text
              v-bind:fill="highlightedLag.color"
              class="time-series__highlight-lag-text"
            >
              {{ highlightedLag.text }}
            </text>
          </g>
        </g>
        <g v-show="effectiveZoomLevel > 1" ref="valuescale" />
        <g v-show="isTimeScaleVisible" ref="timescale" />
        <rect
          v-on:mouseenter.passive.stop.self="showTimeScale"
          v-on:mouseleave.passive.stop.self="hideTimeScale"
          v-on:mousemove.passive.stop.self="onMouseMove"
          class="time-series__interactivity"
          v-bind:x="0"
          v-bind:y="0"
          v-bind:width="width"
          v-bind:height="height"
        ></rect>
        <line
          v-show="isTimestepHighlighted"
          class="time-series__highlight-ts"
          v-bind:x1="highlightedTimestep"
          v-bind:x2="highlightedTimestep"
          v-bind:y1="0"
          v-bind:y2="height"
        />
      </g>
      <g ref="brush" />
    </svg>
  </div>
</template>

<script lang="ts">
import { Component, Prop, Vue } from "vue-property-decorator";
import { scaleLinear, scaleTime, ScaleTime, ScaleLinear } from "d3-scale";
import { isEqual, closestIndexTo, isBefore, isAfter } from "date-fns";
import { line } from "d3-shape";
import { min, max, extent } from "d3-array";
import { interpolateBlues } from "d3-scale-chromatic";
import { SourcePoint } from "@/types/data";
import { mapGetters } from "vuex";
import { axisBottom, axisRight } from "d3-axis";
import { select, selectAll } from "d3-selection";
import { CalendarGranule, CalendarPoint } from "@/types/api";
import pluralize from "pluralize";
import { add } from "@/util/date";
import {
  timeSecond,
  timeMinute,
  timeHour,
  timeDay,
  timeMonth,
  timeWeek,
  timeYear
} from "d3-time";
import { timeFormat } from "d3-time-format";
import { colorLag } from "../util/color";
import { brushX, brushSelection } from "d3-brush";
import { event } from "d3-selection";
import { StoreState } from "../types/store";

type ColorStop = {
  color: string;
  offset: string;
};

export type TSData = {
  value: readonly SourcePoint[];
  color: string;
};

class TimeSeriesClass extends Vue {
  @Prop({ default: () => [] }) public tsdata!: TSData[];
  @Prop({ default: 100 }) public height!: number;
  @Prop({ default: 500 }) public width!: number;
  @Prop({ default: "" }) public id!: string;
  @Prop({ default: "Title" }) public title!: string;
  @Prop({ default: false }) public canHighlightTimestep!: boolean;
  @Prop({ default: false }) public alwaysShowTimeScale!: boolean;
  @Prop({ default: 0 }) public showHighlightedLag!: number;
  @Prop({ default: "day" }) public lagResolution!: CalendarGranule;
  @Prop({ default: "#444" }) public color!: string;
  @Prop({ default: -1 }) public zoom!: number;
  @Prop({ default: false }) public canClickTitle!: boolean;
  @Prop({ default: false }) public useSpecialLabel!: boolean;
  @Prop({ default: () => [0, 0, 0, 0] }) public margin!: [
    number,
    number,
    number,
    number
  ];

  public calendar!: Record<CalendarGranule, CalendarPoint[]>;
  public lagCalendarHighlightMask!: [Date, Date, 0 | 1][];
  public x!: ScaleTime<number, number>;
  public y!: ScaleLinear<number, number>;
  public values!: number[];
  public computedHeight!: number;
  public globalZoomLevel!: number;
  public domain!: [Date, Date];
  public effectiveZoomLevel!: number;

  public timeScaleHeight = this.alwaysShowTimeScale ? this.height : 0;
  public localZoomLevel = this.zoom;
  public heightScalePerZoomLevel = [0.5, 1, 2, 4];
}

@Component<TimeSeriesClass>({
  watch: {
    globalZoomLevel: function(n, o) {
      if (n !== o) {
        this.localZoomLevel = -1;
        this.$emit("updated-height", {
          id: this.id,
          computedHeight: this.computedHeight
        });
      }
    }
  },
  computed: {
    ...mapGetters(["lagCalendarHighlightMask"]),
    globalZoomLevel() {
      return this.$store.state.globalSemanticZoomLevel;
    },
    effectiveZoomLevel() {
      if (this.zoom !== -1) {
        return this.zoom;
      }
      const globalLevel = this.globalZoomLevel;
      if (this.localZoomLevel === -1) {
        return globalLevel;
      }
      return this.localZoomLevel;
    },
    calendar() {
      return this.$store.state.lag.calendar;
    },
    domain() {
      if (this.tsdata.length === 0 || !this.tsdata[0].value) {
        const now = new Date();
        return [now, now];
      }
      const timeRange = (this.$store.state as StoreState).highlightedTimeRange;
      return [timeRange[0], timeRange[timeRange.length - 1]];
    },
    paths() {
      const paths = [];
      for (const series of this.tsdata) {
        if (series.value) {
          const lineGen = line<SourcePoint>()
            .x((d, i) => this.x(d.parsedDate))
            .y(d => this.y(d.value));
          paths.push(lineGen(series.value as any));
        }
      }
      return paths;
    },
    highlightedLag() {
      const cal: CalendarPoint[] = this.calendar[this.lagResolution];
      const l = cal.find(d => d.lag === this.showHighlightedLag);
      if (l === undefined) {
        return;
      }
      return {
        text: `${l.mult} ${pluralize(l.granule, l.mult)}`,
        length: this.x(
          add(this.domain[0], {
            [pluralize(l.granule)]: l.mult
          })
        ),
        color: colorLag(l.lag, this.$store.state.maximumLag)
      };
    },
    x() {
      return scaleTime()
        .domain(this.domain)
        .range([0, this.width]);
    },
    y() {
      const allValues = [];
      for (const ts of this.tsdata) {
        allValues.push(...ts.value.map(v => v.value));
      }
      if (!allValues.length) {
        return scaleLinear()
          .domain([0, 0])
          .range([0, 0]);
      }
      const mi = min(allValues)!;
      const ma = max(allValues)!;
      const extreme = Math.max(Math.abs(mi), Math.abs(ma));
      return scaleLinear()
        .nice()
        .domain([-extreme, extreme])
        .range([this.computedHeight, 0]);
    }
  }
})
export default class TimeSeries extends TimeSeriesClass {
  onMouseMove(event: MouseEvent) {
    if (this.tsdata.length === 0 || !this.tsdata[0].value) {
      return;
    }
    const r = (event.currentTarget as SVGElement).getBoundingClientRect();
    const date = this.x.invert(event.clientX - r.left);
    const index = closestIndexTo(
      date,
      this.tsdata[0].value.map(d => d.parsedDate)
    );
    if (this.canHighlightTimestep) {
      this.$store.dispatch("highlightTimestep", {
        index,
        date:
          this.tsdata[0].value[index] && this.tsdata[0].value[index].parsedDate
      });
    }
  }

  get computedHeight() {
    return (
      this.$props.height * this.heightScalePerZoomLevel[this.effectiveZoomLevel]
    );
  }

  get isTimestepHighlighted() {
    if (!this.canHighlightTimestep) {
      return false;
    }
    return this.$store.state.highlightedTimestep !== undefined;
  }

  get highlightedTimestep() {
    if (!this.isTimestepHighlighted) {
      return 0;
    }
    return this.x(this.$store.state.highlightedTimestep.date);
  }

  get colorstops() {
    const result = [] as ColorStop[];
    const width = this.x.range()[1] - this.x.range()[0];

    function color(bit: number) {
      return bit ? "lightgray" : "white";
    }

    for (const [start, end, v] of this.lagCalendarHighlightMask) {
      result.push({
        color: color(v),
        offset: `${this.x(start) / width}`
      });
      result.push({
        color: color(v),
        offset: `${this.x(end) / width}`
      });
    }
    return result;
  }

  clickHandler(e: MouseEvent) {
    if (e.shiftKey && e.button === 0) {
      if (
        this.effectiveZoomLevel + 1 <=
        this.heightScalePerZoomLevel.length - 1
      ) {
        this.localZoomLevel = this.effectiveZoomLevel + 1;
        this.$emit("updated-height", {
          id: this.id,
          computedHeight: this.computedHeight
        });
      }
    }
  }

  doubleClickHandler(e: MouseEvent) {
    if (!e.shiftKey && e.button === 0) {
      this.$store.dispatch("setHighlightedTimeRange", null);
    }
  }

  preventContext(e: MouseEvent) {
    e.preventDefault();
    this.localZoomLevel = 0;
    this.$emit("updated-height", {
      id: this.id,
      computedHeight: this.computedHeight
    });
  }

  drawAxis() {
    if (this.tsdata.length === 0 || !this.tsdata[0].value) {
      return;
    }

    const brushEl = this.$refs.brush as SVGGElement;
    select(brushEl)
      .on("mouseenter", () => {
        this.showTimeScale();
        brushEl.addEventListener("click", this.clickHandler as EventListener);
        brushEl.addEventListener("contextmenu", this.preventContext);
        brushEl.addEventListener(
          "dblclick",
          this.doubleClickHandler as EventListener
        );
      })
      .on("mouseleave", () => {
        this.hideTimeScale();
        brushEl.removeEventListener(
          "click",
          this.clickHandler as EventListener
        );
        brushEl.removeEventListener("contextmenu", this.preventContext);
        brushEl.removeEventListener(
          "dblclick",
          this.doubleClickHandler as EventListener
        );
      });

    const b = brushX().filter(() => !event.shiftKey && !event.button);
    select(brushEl).call(
      (b as any).on("end", () => {
        const selection = brushSelection(brushEl);
        if (selection !== null) {
          const [start, end] = event.selection.map(this.x.invert);
          this.$store.dispatch("setHighlightedTimeRange", { start, end });
          select(brushEl).call(b.move, null);
        }
      })
    );

    function multiTimeFormat(d: Date) {
      var formatMillisecond = timeFormat(".%L"),
        formatSecond = timeFormat(":%S"),
        formatMinute = timeFormat("%I:%M"),
        formatHour = timeFormat("%H:00"),
        formatDay = timeFormat("%d"),
        formatWeek = timeFormat("%d"),
        formatMonth = timeFormat("%b"),
        formatYear = timeFormat("'%y");
      return (timeSecond(d) < d
        ? formatMillisecond
        : timeMinute(d) < d
        ? formatSecond
        : timeHour(d) < d
        ? formatMinute
        : timeDay(d) < d
        ? formatHour
        : timeMonth(d) < d
        ? timeWeek(d) < d
          ? formatDay
          : formatWeek
        : timeYear(d) < d
        ? formatMonth
        : formatYear)(d);
    }

    const timescale = this.$refs.timescale;
    const timeAxis = axisBottom(this.x as any)
      .tickFormat(multiTimeFormat as any)
      .tickSize(this.computedHeight - 10);
    select(timescale as any)
      .call(timeAxis)
      .call(g => g.selectAll(".domain").remove())
      .call(g =>
        g
          .selectAll(".tick")
          .attr("color", "#999")
          .attr("stroke-dasharray", "1 2")
      )
      .call(g => g.selectAll(".tick text").attr("font-size", 8));

    const valuescale = this.$refs.valuescale as Element;
    const valueAxis = axisRight(this.y).tickSize(this.$props.width);
    select(valuescale)
      .call(valueAxis as any)
      .call(g => g.selectAll(".domain").remove())
      .call(g =>
        g
          .selectAll(".tick line")
          .attr("stroke-opacity", 0.15)
          .attr("stroke-dasharray", "2,2")
      )
      .call(g =>
        g
          .selectAll(".tick text")
          .attr("x", 4)
          .attr("font-size", 8)
          .attr("dy", -4)
      );
  }

  showTimeScale() {
    this.timeScaleHeight = this.$props.height;
  }

  hideTimeScale() {
    this.timeScaleHeight = 0;
  }

  get isTimeScaleVisible() {
    if (this.alwaysShowTimeScale) {
      return true;
    }
    return this.timeScaleHeight > 0 || this.effectiveZoomLevel > 1;
  }

  mounted() {
    this.drawAxis();
    if (this.id) {
      this.$emit("updated-height", {
        id: this.id,
        computedHeight: this.computedHeight
      });
    }
  }

  updated() {
    this.drawAxis();
  }

  handleClick() {
    this.$emit("click");
  }
}
</script>
<style scoped lang="less">
.time-series {
  display: flex;
  align-items: center;
  user-select: none;

  svg {
    transform: translateZ(0);
  }

  &__title {
    margin-right: 2px;
    font-family: "Monaco", "Courier New", Courier, monospace;
    font-size: 12px;
    user-select: none;

    &--clickable {
      cursor: pointer;
      &:hover {
        text-decoration: underline;
      }
    }

    &--special {
      font-weight: 700;
    }
  }

  &__line {
    pointer-events: none;
  }

  &__stat {
    stroke-width: 10;
  }

  &__interactivity {
    fill: none;
    pointer-events: all;
  }

  &__highlight-ts {
    stroke-width: 1px;
    stroke: red;
    fill: none;
  }

  &__highlight-lag {
    stroke-width: 1px;
  }

  &__highlight-lag-text {
    font-size: 6px;
  }
}

path {
  fill: none;
  opacity: 0.8;
  stroke-width: 1px;
  user-select: none;
}
</style>
