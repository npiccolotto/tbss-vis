<template>
  <div>
    <svg v-bind:width="width" v-bind:height="height">
      <g ref="scale" />
      <g
        v-bind:transform="
          'rotate(180,0,0)translate(-' +
            x(val.value) +
            ',-' +
            (y(multiplicities[val.value.toFixed(2)].indexOf(val.id)) - 4) +
            ')'
        "
        v-for="val in values"
        v-bind:key="val.id"
      >
        <path v-bind:d="triangle()" v-bind:fill="val.color">
          <title>{{ val.value }}</title>
        </path>
      </g>
    </svg>
  </div>
</template>

<script lang="ts">
import { Vue, Component, Prop } from "vue-property-decorator";
import { scaleLinear, ScaleLinear } from "d3-scale";
import { axisBottom } from "d3-axis";
import { format } from "d3-format";
import { symbol, symbolTriangle } from "d3-shape";
import { select } from "d3-selection";
import { formatInteger } from "../util/util";

class WeightClass extends Vue {
  @Prop({ default: 50 }) public height!: number;
  @Prop({ default: 400 }) public width!: number;
  @Prop({ default: 30 }) public markerSideLength!: number;
  @Prop({ default: () => [] }) public values!: {
    value: number;
    color: string;
    id: string;
  }[];
  @Prop({ default: () => [5, 10, 5, 10] }) public margin!: [
    number,
    number,
    number,
    number
  ];
  public scaleHeight = 20;
  public x!: ScaleLinear<number, number>;
}

@Component<WeightClass>({
  computed: {
    center() {
      return (this.$props.height - this.$props.margin[0]) / 2;
    },
    triangle() {
      return symbol()
        .size(this.markerSideLength)
        .type(() => symbolTriangle);
    },
    x() {
      return scaleLinear()
        .domain([0, 1])
        .range([
          this.$props.margin[3],
          this.$props.width - this.$props.margin[1]
        ]);
    },
    y() {
      return scaleLinear()
        .domain([0, 4])
        .range([
          this.height - this.margin[2] - this.scaleHeight,
          this.margin[0]
        ]);
    }
  }
})
export default class Weight extends WeightClass {
  get multiplicities() {
    const result: Record<string, string[]> = {};
    for (let i = 0; i <= 100; i++) {
      result[(i / 100).toFixed(2)] = [];
    }
    for (const val of this.values) {
      result[val.value.toFixed(2)].push(val.id);
    }
    return result;
  }

  mounted() {
    this.drawAxis();
  }

  updated() {
    this.drawAxis();
  }

  drawAxis() {
    const tickValues = [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1];
    select(this.$refs.scale as Element)
      .call(
        axisBottom(this.x)
          .tickFormat(format(".2f"))
          .tickValues(tickValues) as any
      )
      .call(g =>
        g.attr(
          "transform",
          `translate(0, ${this.height - this.margin[2] - this.scaleHeight})`
        )
      );
  }
}
</script>

<style lang="less" scoped></style>
