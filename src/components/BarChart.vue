<template>
  <div class="bar-chart">
    <svg v-bind:width="width" v-bind:height="height">
      <rect
        class="bar-chart__rect"
        v-for="val in bcdata"
        v-bind:key="val.x"
        v-bind:width="x.bandwidth()"
        v-bind:height="y(0) - y(val.y)"
        v-bind:y="y(val.y)"
        v-bind:x="x(val.x)"
        v-bind:fill="val.color"
      />

      <g ref="scaley" />
    </svg>
  </div>
</template>

<script lang="ts">
import { Component, Prop, Vue } from "vue-property-decorator";
import { scaleLinear, ScaleBand, ScaleLinear, scaleBand } from "d3-scale";
import { line } from "d3-shape";
import { min, max, extent } from "d3-array";
import { axisBottom, axisRight } from "d3-axis";
import { select, selectAll } from "d3-selection";
import { StoreState } from "../types/store";

type BarChartPoint = {
  x: string;
  y: number;
  color: string;
};

class BarChartClass extends Vue {
  @Prop({ default: () => [] }) public bcdata!: BarChartPoint[];
  @Prop({ default: 50 }) public height!: number;
  @Prop({ default: 50 }) public width!: number;
  @Prop({ default: () => [5, 5, 0, 5] }) public margin!: [
    number,
    number,
    number,
    number
  ];
  public x!: ScaleBand<number>;
  public y!: ScaleLinear<number, number>;

  public values!: number[];
}

@Component<BarChartClass>({
  computed: {
    values() {
      return this.bcdata.map(bc => bc.y);
    },
    x() {
      return scaleBand()
        .domain(this.bcdata.map(bc => bc.x))
        .range([this.margin[3], this.width - this.margin[1]])
        .paddingInner(0.1);
    },
    y() {
      return scaleLinear()
        .domain([0, max(this.values)!])
        .range([this.height - this.margin[2], this.margin[0]])
        .nice();
    }
  }
})
export default class BarChart extends BarChartClass {
  drawAxis() {
    if (this.bcdata.length === 0) {
      return;
    }

    const scaley = this.$refs.scaley as SVGGElement;
    const yAxis = axisRight(this.y)
      .tickSize(this.$props.width)
      .ticks(3);
    select(scaley)
      .call(yAxis)
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

  mounted() {
    this.drawAxis();
  }

  updated() {
    this.drawAxis();
  }
}
</script>
<style scoped lang="less">
.bar-chart {
  display: flex;
  align-items: center;

  svg {
    transform: translateZ(0);
  }
}

path {
  fill: none;
  opacity: 0.8;
  stroke-width: 1px;
}
</style>
