<template>
  <svg
    v-bind:height="height + margin[0] + margin[2]"
    v-bind:width="width + margin[1] + margin[3]"
  >
    <g v-bind:transform="'translate(' + margin[1] + ',' + margin[0] + ')'">
      <g ref="scale" />
      <g
        v-bind:transform="
          'rotate(180,' + x(weight) + ',10)translate(' + x(weight) + ',10)'
        "
      >
        <path v-bind:d="triangle()" v-bind:fill="color">
          <title>{{ weight }}</title>
        </path>
      </g>
    </g>
  </svg>
</template>
<script lang="ts">
import { Vue, Prop, Component } from "vue-property-decorator";
import { scaleLinear, ScaleLinear, scalePow } from "d3-scale";
import { symbol, symbolTriangle } from "d3-shape";
import { select } from "d3-selection";
import { axisBottom } from "d3-axis";
class VerticalWeightClass extends Vue {
  @Prop({ default: 0 }) public weight!: number;
  @Prop({ default: "black" }) public color!: string;
  @Prop({ default: 40 }) public width!: number;
  @Prop({ default: 25 }) public height!: number;
  @Prop({ default: () => [0, 5, 0, 5] }) public margin!: [
    number,
    number,
    number,
    number
  ];

  public x!: ScaleLinear<number, number>;
  public markerSideLength = 5;
}

@Component<VerticalWeightClass>({
  computed: {
    x: function() {
      const x: ScaleLinear<number, number> = scalePow()
        .exponent(2)
        .domain([0, 1])
        .range([this.margin[3], this.width - this.margin[1]]);
      return x;
    },
    triangle() {
      return symbol()
        .size(5 * this.markerSideLength)
        .type(() => symbolTriangle);
    }
  }
})
export default class VerticalWeight extends VerticalWeightClass {
  mounted() {
    this.drawAxis();
  }

  updated() {
    this.drawAxis();
  }

  drawAxis() {
    if (!this.$refs.scale) {
      return;
    }
    const axis = axisBottom(this.x)
      .tickValues([0, 0.75, 1])
      .tickSize(2);
    select(this.$refs.scale as Element)
      .call(axis as any)
      .call(g => g.attr("transform", "translate(0,15)"))
      .call(g => g.selectAll(".tick text").attr("font-size", 6));
  }
}
</script>

<style lang="less" scoped>
svg {
}
</style>
