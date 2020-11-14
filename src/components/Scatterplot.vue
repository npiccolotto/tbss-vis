<template>
  <svg v-bind:width="width" v-bind:height="height">
    <g v-bind:transform="'translate(' + width / 2 + ',' + height + ')'">
      <text>{{ source }}</text>
    </g>
    <g ref="scaley" class="scatterplot__scale"></g>
    <g
      v-bind:transform="
        'translate(' + width + ',' + (height - margin[0]) + ')rotate(270,0,0)'
      "
    >
      <text>{{ source }} + {{ lag }}</text>
    </g>
    <g ref="scalex" class="scatterplot__scale"></g>
    <g>
      <circle
        class="scatterplot__point"
        v-bind:fill="color"
        v-bind:key="pointIndex"
        v-for="(point, pointIndex) in points.data"
        v-bind:cx="point[0]"
        v-bind:cy="point[1]"
        r="1"
      />
    </g>
  </svg>
</template>

<script lang="ts">
import { Vue, Prop, Component } from "vue-property-decorator";
import { scaleLinear, ScaleLinear } from "d3-scale";
import { extent } from "d3-array";
import zip from "lodash-es/zip";
import { colorLag } from "@/util/color";
import { axisBottom, axisRight } from "d3-axis";
import { select } from "d3-selection";

@Component({
  computed: {
    color() {
      return colorLag(this.$props.lag, this.$store.state.maximumLag);
    },
    points() {
      const raw = this.$store.state.sources.raw[this.$props.source];
      if (!raw) {
        return { data: [] };
      }

      const lagX: number[] = [];
      const lagY: number[] = [];
      let i = 0;
      while (i + this.$props.lag < this.$store.state.sources.n) {
        const t1 = i;
        const t2 = i + this.$props.lag;
        lagX.push(raw[t1].value);
        lagY.push(raw[t2].value);
        i += 1;
      }

      const [top, right, bottom, left] = this.$props.margin;
      const [xMin, xMax] = extent(lagX) as [number, number];
      const [yMin, yMax] = extent(lagY) as [number, number];

      const extreme = Math.max(
        ...[xMin, xMax, yMin, yMax].map(x => Math.abs(x))
      );
      const domain = [-extreme, extreme];

      const x = scaleLinear()
        .domain(domain)
        .range([left, this.$props.width - right]);
      const y = scaleLinear()
        .domain(domain)
        .range([this.$props.height - top, bottom]);
      return {
        data: zip(lagX, lagY).map(([px, py]) => [x(px!), y(py!)]),
        x,
        y
      };
    }
  }
})
export default class Scatterplot extends Vue {
  @Prop({ required: true, default: "AUD" })
  private source!: string;
  @Prop({ required: true, default: 10, type: Number })
  private lag!: number;
  @Prop({ default: 250, type: Number })
  private width!: number;
  @Prop({ default: 250, type: Number })
  private height!: number;
  private points!: {
    data: number[][];
    x: ScaleLinear<number, number>;
    y: ScaleLinear<number, number>;
  };
  @Prop({ default: () => [10, 10, 10, 10] })
  private margin!: [number, number, number, number];

  drawAxis() {
    const el = this.$refs.scaley as Element;
    const bottomEl = this.$refs.scalex as Element;
    const { x, y, data } = this.points;
    if (data.length === 0) {
      return;
    }

    const axisB = axisBottom(x)
      .ticks(3)
      .tickSize(0);
    select(bottomEl)
      .call(axisB as any)
      .call(g => g.select(".domain").remove())
      .call(g => g.selectAll(".tick text").attr("dy", 4));

    const axisR = axisRight(y)
      .tickSize(0)
      .ticks(3);
    select(el)
      .call(axisR as any)
      .call(g => g.select(".domain").remove())
      .call(g =>
        g
          .selectAll(".tick line")
          .attr("stroke-opacity", 0.15)
          .attr("stroke-dasharray", "2,2")
      )
      .call(g =>
        g
          .selectAll(".tick text")
          .attr("x", 0)
          .attr("dy", 0)
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

<style lang="less" scoped>
.scatterplot__point {
}
</style>
