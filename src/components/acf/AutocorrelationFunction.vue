<template>
  <div>
    <div
      style="display:grid; grid-template-columns: repeat(2, max-content); grid-gap: 15px;"
    >
      <label for="value">
        <input type="radio" id="value" value="value" v-model="sortOrder" /> sort
        ACF by value</label
      >

      <label for="variable"
        ><input
          type="radio"
          id="variable"
          value="variable"
          v-model="sortOrder"
        />
        sort ACF by variable</label
      >
    </div>

    <svg class="acf" v-bind:width="width" v-bind:height="height">
      <g
        class="acf__container"
        v-bind:transform="'translate(' + margin[3] + ',' + margin[0] + ')'"
      >
        <line
          class="acf__whitenoise"
          v-bind:x1="zeroline[0]"
          v-bind:y1="whitenoiselineypos"
          v-bind:x2="zeroline[0] + width - margin[1] - margin[3]"
          v-bind:y2="whitenoiselineypos"
        />

        <line
          class="acf__whitenoise"
          v-bind:x1="zeroline[0]"
          v-bind:y1="whitenoiselineyneg"
          v-bind:x2="zeroline[0] + width - margin[1] - margin[3]"
          v-bind:y2="whitenoiselineyneg"
        />
        <g class="acf__laginfo--primary" v-if="lagSteps.length > 0">
          <rect
            v-bind:key="'primarystep' + step"
            v-for="(step, stepindex) in lagSteps"
            v-bind:class="{
              'acf__laginfo-rect': true,
              selected: selectedLags.includes(displayData[stepindex][0].lag),
              highlighted: highlightedLag === displayData[stepindex][0].lag
            }"
            v-bind:x="step"
            v-bind:y="0"
            v-bind:width="colwidth"
            v-bind:height="height - margin[2] - margin[0]"
            v-on:mouseover="highlight(stepindex)"
            v-on:click="selectLag(stepindex)"
          />
        </g>
        <g ref="scaley" class="acf__scale"></g>
        <g ref="scalex" class="acf__scale"></g>
        <g v-bind:key="step" v-for="(step, stepindex) in lagSteps">
          <text
            v-bind:class="{
              'acf__lag-label': true,
              highlighted: highlightedLag === displayData[stepindex][0].lag,
              selected: selectedLags.includes(displayData[stepindex][0].lag)
            }"
            v-bind:transform="
              'translate(' +
                (lines[stepindex][0].points[0] + 2 + colwidth / 2) +
                ', 0)rotate(270)'
            "
          >
            {{ lines[stepindex][0].lag }}
          </text>
          <line
            v-bind:class="{
              acf__marker: true,
              highlighted: highlightedVar === line.variable
            }"
            v-for="(line, lineindex) in lines[stepindex]"
            v-bind:key="lineindex"
            v-bind:data-lag="line.lag"
            v-bind:data-variable="line.variable"
            v-on:mouseover="highlight(stepindex)"
            v-bind:stroke="color(line.lag)"
            v-bind:x1="line.points[0] + line.points[2]"
            v-bind:y1="zeroline[1]"
            v-bind:x2="line.points[0] + line.points[2]"
            v-bind:y2="line.points[1]"
          />
        </g>
      </g>
    </svg>
    <span v-if="selectedLags.length" />
  </div>
</template>

<script lang="ts">
import { Component, Prop, Vue } from "vue-property-decorator";
import { ACFPoint } from "@/types/api";
import group from "lodash-es/groupBy";
import flatten from "lodash-es/flatten";
import { axisBottom, axisRight } from "d3-axis";
import { scaleLinear } from "d3-scale";
import { extent } from "d3-array";
import { select } from "d3-selection";
import range from "lodash-es/range";
import { colorLag } from "@/util/color";
import { format } from "d3-format";
import { DirectiveBinding } from "vue/types/options";
import { StoreState } from "@/types/store";
import { LagInformation } from "@/types/display";

class ACFClass extends Vue {
  @Prop({ default: 200 }) public height!: number;
  @Prop({ default: 500 }) public width!: number;
  @Prop({ default: () => [10, 10, 0, 10] }) public margin!: number[];
  @Prop({ default: () => [] }) public brushedLags!: number[];
  @Prop({ default: () => [] }) public selectedLags!: number[];

  public maximumLag!: number;
  public displayData!: ACFPoint[][];
  public sortOrder: "variable" | "value" = "value";
}

@Component<ACFClass>({
  computed: {
    displayData() {
      let data = (this.$store.state as StoreState).acf.bylag || [];
      if (data.length === 0) {
        return [];
      }
      data = data.filter((d, i) => this.brushedLags.includes(i + 1));
      return data;
    },
    highlightedLag() {
      return this.$store.state.highlightedLag;
    },
    highlightedVar() {
      return this.$store.state.highlightedVar;
    },
    maximumLag() {
      return this.$store.state.maximumLag;
    }
  }
})
export default class AutocorrelationFunction extends ACFClass {
  get scaleoffset() {
    return 30;
  }

  color(lag: number) {
    return colorLag(lag, this.maximumLag);
  }

  get colwidth() {
    return (
      (this.$props.width - this.margin[1] - this.margin[3] - this.scaleoffset) /
      this.displayData.length
    );
  }

  get sourcelength() {
    return this.$store.state.sources.n;
  }

  get y() {
    // Enforce symmetry
    const allVisibleACFValues = this.displayData.flat().map(acf => acf.value);
    const [min, max] = extent(allVisibleACFValues);
    const extreme = Math.max(Math.abs(min!), Math.abs(max!));
    return scaleLinear()
      .domain([-extreme, extreme])
      .range([
        this.$props.height - this.margin[0] - this.margin[2],
        this.margin[2]
      ]);
  }

  get x() {
    return scaleLinear()
      .domain([0, this.displayData.length])
      .range([this.scaleoffset, this.$props.width - this.margin[1]]);
  }

  get xInner() {
    return scaleLinear()
      .domain([0, this.$store.state.sources.p])
      .range([2, this.colwidth - 2]);
  }

  get whitenoiselineyneg() {
    return this.y(this.$store.state.acf.whitenoiseBorders[0]);
  }

  get whitenoiselineypos() {
    return this.y(this.$store.state.acf.whitenoiseBorders[1]);
  }

  get zeroline() {
    return [this.x(0), this.y(0)];
  }

  get lagSteps() {
    return range(this.displayData.length).map(s => this.x(s));
  }

  get lines() {
    const projectedPoints = this.displayData.map((acfPoints, i) => {
      const sortedPoints =
        this.sortOrder === "value"
          ? acfPoints.sort((a, b) => b.value - a.value)
          : acfPoints.sort((a, b) =>
              a.variable < b.variable ? -1 : a.variable > b.variable ? 1 : 0
            );

      return sortedPoints.map((point, j) => ({
        i,
        lag: point.lag,
        variable: point.variable,
        points: [this.x(i), this.y(point.value), this.xInner(j + 0.5)]
      }));
    });
    return group(flatten(projectedPoints), "i");
  }

  drawAxisY() {
    const el = this.$refs.scaley as Element;
    const axisR = axisRight(this.y)
      .tickSize(this.$props.width)
      .tickFormat(format(",.2f"));
    select(el)
      .call(axisR as any)
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
          .attr("dy", -2)
      );
  }

  drawAxisX() {
    const bottomEl = this.$refs.scalex as Element;

    const tickLabels = this.displayData.map(acfPoints => acfPoints[0].lag);
    const tickValues = range(this.displayData.length).map(l => l + 0.5);
    const axisB = axisBottom(this.x)
      .tickSize(0)
      .tickValues([]);
    select(bottomEl)
      .call(axisB as any)
      .call(g => g.selectAll(".domain").remove())
      .call(g => g.selectAll(".tick text").attr("dy", -4));
  }

  highlight(stepIndex: number) {
    const lag = this.displayData[stepIndex][0].lag;
    this.$store.dispatch("setHighlightedLag", lag);
  }

  selectLag(stepIndex: number) {
    const lag = this.displayData[stepIndex][0].lag;
    this.$emit("select-lag", lag);
  }

  updated() {
    this.drawAxisX();
    this.drawAxisY();
  }
  mounted() {
    this.drawAxisY();
    this.drawAxisX();
  }
}
</script>
<style scoped lang="less">
.acf {
  &__marker {
    opacity: 0.8;
    stroke-width: 1px;
    fill: none;
    cursor: pointer;

    &.highlighted {
      stroke: black;
    }
  }

  &__lag-label {
    user-select: none;
    font-size: 10px;
    fill: lightgray;
    text-anchor: end;

    &.selected,
    &.highlighted {
      font-weight: bold;
      fill: darkgray;
    }
  }

  &__laginfo-rect {
    cursor: pointer;
    stroke: lightgray;
    stroke-width: 1px;
    fill: rgba(0, 0, 0, 0);

    &.highlighted {
      fill: rgba(0, 0, 0, 0.2);
    }

    &.selected {
      stroke: gray;
    }
  }

  &__whitenoise {
    stroke: steelblue;
    fill: none;
  }
}
</style>
