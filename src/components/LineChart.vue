<template>
  <div class="line-chart">
    <svg v-bind:width="width" v-bind:height="height + 2 * yLegendMargin">
      <g v-for="(series, sidx) in lcdata" v-bind:key="sidx">
        <path
          class="line-chart__line"
          v-bind:d="path(series.value)"
          v-bind:stroke="series.color"
        />
        <g
          v-for="(tick, tidx) in ticks1"
          v-bind:key="'tick0-' + sidx + ',' + tidx"
          v-bind:transform="'translate(' + tick.x + ',0)'"
        >
          <rect
            v-bind:fill="tick.color"
            v-bind:width="tick.width"
            v-bind:height="tick.height"
            v-bind:y="tick.y"
          >
            <title>
              {{ tick.bin.binStart }}–{{ tick.bin.binEnd }}:
              {{ tick.bin.lagsInBin.length }}
            </title>
          </rect>
        </g>
        <g
          v-for="(tick, tidx) in ticks2"
          v-bind:key="'tick1-' + sidx + ',' + tidx"
          v-bind:transform="
            'translate(' + tick.x + ',' + (height + 3 - yLegendMargin) + ')'
          "
        >
          <rect
            v-bind:fill="tick.color"
            v-bind:width="tick.width"
            v-bind:height="tick.y"
          >
            <title>
              {{ tick.bin.binStart }}–{{ tick.bin.binEnd }}:
              {{ tick.bin.lagsInBin.length }}
            </title>
          </rect>
        </g>
      </g>
      <g v-bind:transform="'translate(' + 0 + ',' + (height + 20) + ')'">
        <text text-anchor="start" font-size="10">
          {{ xAxisName }} &rightarrow;
        </text>
      </g>
      <g>
        <g ref="scalex"></g>
        <g ref="scaley"></g>
      </g>
      <g ref="brush"></g>
    </svg>
  </div>
</template>

<script lang="ts">
import { Component, Prop, Vue } from "vue-property-decorator";
import { scaleLinear, ScaleLinear } from "d3-scale";
import { isEqual, closestIndexTo, isBefore, isAfter } from "date-fns";
import { line } from "d3-shape";
import { min, max, extent } from "d3-array";
import { interpolateBlues } from "d3-scale-chromatic";
import { mapGetters } from "vuex";
import { axisBottom, axisTop, axisRight } from "d3-axis";
import { select, selectAll } from "d3-selection";
import { CalendarGranule, CalendarPoint } from "@/types/api";
import pluralize from "pluralize";
import { format } from "d3-format";
import { add } from "@/util/date";
import { symbol, symbolTriangle } from "d3-shape";
import { colorLag } from "../util/color";
import { brushX, brushSelection } from "d3-brush";
import { event } from "d3-selection";
import { StoreState } from "../types/store";
import { binLagSet, Bin } from "@/util/util";

type LineChartPoint = {
  x: number;
  y: number;
};
export type LineChartData = {
  value: LineChartPoint[];
  color: string;
  tickBinSize: number;
  ticks: [number[], number[]];
}[];

class LineChartClass extends Vue {
  @Prop({ default: () => [] }) public lcdata!: LineChartData;
  @Prop({ default: 100 }) public height!: number;
  @Prop({ default: 500 }) public width!: number;

  @Prop({ default: "" }) public xAxisName!: string;
  @Prop({ default: "" }) public yAxisName!: string;

  public x!: ScaleLinear<number, number>;
  public y!: ScaleLinear<number, number>;
  public tickY!: {
    y1: ScaleLinear<number, number>;
    y2: ScaleLinear<number, number>;
  };

  public values!: number[];
  public xLegendMargin = 50;
  public yLegendMargin = 15;
  public ticks1Bins!: Bin[];
  public ticks2Bins!: Bin[];
}

@Component<LineChartClass>({
  computed: {
    triangle() {
      return symbol()
        .size(15)
        .type(() => symbolTriangle);
    },
    ticks1Bins() {
      const y1Bins = binLagSet(
        this.lcdata[0].ticks[0],
        this.lcdata[0].tickBinSize,
        this.$store.state.maximumLag
      );
      return y1Bins;
    },
    ticks2Bins() {
      const y2Bins = binLagSet(
        this.lcdata[0].ticks[1],
        this.lcdata[0].tickBinSize,
        this.$store.state.maximumLag
      );
      return y2Bins;
    },
    tickY() {
      const y1LargestBin = Math.max(
        ...this.ticks1Bins.map(b => b.lagsInBin.length)
      );
      const y2LargestBin = Math.max(
        ...this.ticks2Bins.map(b => b.lagsInBin.length)
      );
      const largestBin = Math.max(y1LargestBin, y2LargestBin);
      const y1 = scaleLinear()
        .domain([largestBin, 0])
        .range([0, this.yLegendMargin]);

      const y2 = scaleLinear()
        .domain([0, largestBin])
        .range([0, this.yLegendMargin - 3]);
      return { y1, y2 };
    },
    ticks1() {
      return this.ticks1Bins.map(bin => {
        const isEmpty = bin.lagsInBin.length === 0;
        const value = !isEmpty ? bin.lagsInBin[0] : -1;
        const color = colorLag(
          value,
          this.lcdata[0].value.length,
          this.lcdata[0].color
        );
        const width = this.x(bin.binWidth) - this.x(0);
        const x = this.x(bin.binStart);
        const y = this.tickY.y1(bin.lagsInBin.length);
        const height = this.tickY.y1(0) - y;
        return {
          bin,
          x,
          y,
          height,
          width,
          isEmpty,
          value,
          color
        };
      });
    },
    ticks2() {
      return this.ticks2Bins.map(bin => {
        const isEmpty = bin.lagsInBin.length === 0;
        const value = !isEmpty ? bin.lagsInBin[0] : -1;
        const color = colorLag(
          value,
          this.lcdata[0].value.length,
          this.lcdata[0].color
        );
        const width = this.x(bin.binWidth) - this.x(0);
        const x = this.x(bin.binStart);
        const y = this.tickY.y2(bin.lagsInBin.length);
        return {
          bin,
          x,
          y,
          isEmpty,
          width,
          value,
          color
        };
      });
    },
    values() {
      const allValues = [];
      for (const lc of this.lcdata) {
        allValues.push(...lc.value.map(v => v.y));
      }
      return allValues;
    },
    x() {
      const state = this.$store.state as StoreState;

      const lagRange = state.highlightedLagRange;
      const domain = [lagRange[0], lagRange[lagRange.length - 1]];
      return scaleLinear()
        .domain(domain)
        .range([this.xLegendMargin, this.width]);
    },
    y() {
      const mi = min(this.values)!;
      const ma = max(this.values)!;
      const extreme = Math.max(Math.abs(mi), Math.abs(ma));
      return scaleLinear()
        .domain([0, extreme])
        .range([this.height - this.yLegendMargin, this.yLegendMargin]);
    }
  }
})
export default class LineChart extends LineChartClass {
  path(values: LineChartPoint[]) {
    if (!values || !values.length) {
      return "";
    }
    const lineGen = line<LineChartPoint>()
      .x((d, i) => this.x(d.x))
      .y(d => this.y(d.y));
    return lineGen(values);
  }

  doubleClickHandler(e: MouseEvent) {
    if (!e.shiftKey && e.button === 0) {
      this.$store.dispatch("setHighlightedLagRange", null);
    }
  }

  drawAxis() {
    if (this.lcdata.length === 0 || !this.lcdata[0].value) {
      return;
    }

    const scalex = this.$refs.scalex as SVGGElement;
    const xAxis = axisBottom(this.x)
      .tickFormat(d => (Math.floor(d as any) !== d ? "" : d + ""))
      .tickSize(this.height - 1 * this.yLegendMargin)
      .tickPadding(3);
    select(scalex)
      .call(xAxis)
      .call(g => g.attr("transform", `translate(0,${this.yLegendMargin})`))
      .call(g => g.selectAll(".domain").remove())
      .call(g =>
        g
          .selectAll(".tick line")
          .attr("stroke-opacity", 0.3)
          .attr("stroke-dasharray", "2 2")
      )
      .call(g => g.selectAll(".tick text").attr("font-size", 8));
    const brushEl = this.$refs.brush as SVGGElement;
    const b = brushX()
      .extent([
        [0, this.yLegendMargin],
        [this.width, this.height - this.yLegendMargin]
      ])
      .filter(() => !event.shiftKey && !event.button);
    select(brushEl)
      .on("mouseenter", () => {
        brushEl.addEventListener(
          "dblclick",
          this.doubleClickHandler as EventListener
        );
      })
      .on("mouseleave", () => {
        brushEl.removeEventListener(
          "dblclick",
          this.doubleClickHandler as EventListener
        );
      });
    select(brushEl).call(
      (b as any).on("end", () => {
        const selection = brushSelection(brushEl);
        if (selection !== null) {
          const [start, end] = event.selection.map(this.x.invert);
          this.$store.dispatch("setHighlightedLagRange", { start, end });
          select(brushEl).call(b.move, null);
        }
      })
    );

    const scaley = this.$refs.scaley as SVGGElement;
    const yAxis = axisRight(this.y)
      .ticks(4)
      .tickSize(this.$props.width);
    select(scaley)
      .call(yAxis)
      .call(g => g.selectAll(".domain").remove())
      .call(g =>
        g
          .selectAll(".tick line")
          .attr("stroke-opacity", 0.3)
          .attr("stroke-dasharray", "2 2")
      )
      .call(g =>
        g
          .selectAll(".tick text")
          .attr("x", 4)
          .attr("font-size", 8)
          .attr("dy", -1)
      );
  }

  mounted() {
    this.drawAxis();
  }

  updated() {
    this.drawAxis();
  }
}
</script>
<style scoped lang="less">
.line-chart {
  display: flex;
  align-items: center;

  svg {
    transform: translateZ(0);
  }
}

.line-chart__line {
  fill: none;
  opacity: 0.8;
  stroke-width: 1px;
}
</style>
