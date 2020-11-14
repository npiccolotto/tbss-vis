<template>
  <svg v-bind:width="width" v-bind:height="height">
    <rect
      v-for="(d, bidx) in scales.bins"
      v-bind:key="bidx + 'bg'"
      v-bind:width="width / scales.bins.length"
      v-bind:x="(width / scales.bins.length) * bidx"
      v-bind:y="0"
      v-bind:height="scales.y(0)"
      fill="white"
    >
      <title>Lags used {{ d.x0 }}-{{ d.x1 }}: {{ d.length }}</title>
    </rect>
    <rect
      v-for="(d, bidx) in scales.bins"
      v-bind:key="bidx"
      v-bind:width="width / scales.bins.length"
      v-bind:x="(width / scales.bins.length) * bidx"
      v-bind:y="scales.y(d.length)"
      v-bind:height="scales.y(0) - scales.y(d.length)"
      fill="black"
    >
      <title>Lags used {{ d.x0 }}-{{ d.x1 }}: {{ d.length }}</title>
    </rect>
    <line
      v-bind:x1="0"
      v-bind:x2="width"
      v-bind:y1="height"
      v-bind:y2="height"
      stroke="gray"
      fill="none"
    />
  </svg>
</template>
<script lang="ts">
import { Vue, Prop, Component } from "vue-property-decorator";
import { extent, histogram } from "d3-array";
import { scaleLinear, ScaleLinear } from "d3-scale";
import range from "lodash-es/range";

class HistogramClass extends Vue {
  @Prop({ default: 10 }) public numBins!: number;
  @Prop({ default: 40 }) public width!: number;
  @Prop({ default: 20 }) public height!: number;
  @Prop({ default: () => [] }) public values!: number[];
  @Prop({ default: 0 }) public maxHeightValue!: number;
}

@Component<HistogramClass>({
  computed: {
    scales: function() {
      const [min, max] = extent(this.values);
      const x: ScaleLinear<number, number> = scaleLinear()
        .domain([1, this.$store.state.maximumLag])
        .range([0, this.width]);
      const m =
        Math.ceil(this.$store.state.maximumLag / this.numBins / 100) * 100;
      const thresholds = range(this.numBins).map(b => b * m);
      const h = histogram()
        .domain(x.domain() as any)
        .thresholds(thresholds);
      const bins = h(this.values);
      const y: ScaleLinear<number, number> = scaleLinear()
        .domain([Math.min(...bins.map(b => b.length)), this.maxHeightValue])
        .range([this.height, 0]);
      return {
        x,
        y,
        bins
      };
    }
  }
})
export default class Histogram extends HistogramClass {}
</script>
