<template>
  <div
    class="guided-slider"
    v-bind:style="{
      width: width + (showYScale ? 20 : 0) + 'px'
    }"
  >
    <div class="description">
      <div class="legend__label">{{ legendGuidance }}</div>
    </div>
    <div class="legend">
      <div class="legend__label">{{ legendGuidanceLow }}</div>
      <div class="legend__label">{{ legendGuidanceHigh }}</div>
    </div>
    <div>
      <div>
        <svg
          v-bind:width="width + (showYScale ? 20 : 0)"
          v-bind:height="height + 10"
        >
          <g v-bind:transform="'translate(' + (showYScale ? 20 : 0) + ',10)'">
            <g>
              <rect
                v-for="(val, i) in values"
                v-bind:key="String(i) + 'data'"
                v-bind:data-guidance="val.guidanceValue"
                v-bind:data-value="val.value"
                v-bind:y="scales.y(val.guidanceValue)"
                v-bind:x="scales.x(String(val.value))"
                v-bind:height="
                  height - legendHeight - scales.y(val.guidanceValue)
                "
                v-bind:width="scales.x.bandwidth()"
                v-bind:class="{
                  weight: true,
                  // No idea why it needs to be like this
                  selected: selectedValueIndex - i === 0
                }"
              >
                <title>{{ val.guidanceValue }}</title>
              </rect>
            </g>
            <g ref="scaley" class="acf__scale"></g>
            <g ref="scalex" class="acf__scale"></g>
          </g>
        </svg>

        <div v-bind:style="{ marginLeft: showYScale ? '20px' : '0px' }">
          <div
            v-bind:style="{
              marginLeft:
                scales.x.bandwidth() / 2 -
                rangeInputBubbleWidthPlusPadding / 2 +
                'px',
              marginRight:
                scales.x.bandwidth() / 2 -
                rangeInputBubbleWidthPlusPadding / 2 +
                'px'
            }"
          >
            <input
              type="range"
              v-model.number.lazy="selectedValueIndex"
              v-bind:min="0"
              v-bind:max="values.length - 1"
              v-bind:step="1"
            />
          </div>
        </div>
        <div class="description">
          <div class="legend__label">{{ legendValue }}: {{ value }}</div>
        </div>
      </div>
    </div>
    <input
      v-if="allowDirectInput"
      type="number"
      v-model.number="selectedValue"
      min="0"
      max="1"
      step="0.01"
    />
  </div>
</template>

<script lang="ts">
import { Vue, Prop, Component, Model } from "vue-property-decorator";
import { histogram } from "d3-array";
import range from "lodash-es/range";
import { format } from "d3-format";
import { axisBottom, axisRight, axisLeft, axisTop } from "d3-axis";
import { scaleLinear, ScaleLinear, scaleBand, ScaleBand } from "d3-scale";
import { select } from "d3-selection";
import { formatInteger } from "../../util/util";

class GuidedSliderClass extends Vue {
  @Prop({ type: Number, default: 500 }) public width!: number;
  @Prop({ type: Number, default: 120 }) public height!: number;
  @Prop({ type: Boolean, default: false }) public allowDirectInput!: boolean;
  @Prop({ type: Number, default: 1 }) public ticksEvery!: number;
  @Prop({ type: String, default: "index" }) public ticksBy!: "value" | "index";
  @Prop({ type: String, default: "" }) public legendValue!: string;
  @Prop({ type: String, default: "" }) public legendGuidance!: string;
  @Prop({ type: String, default: "" }) public legendGuidanceLow!: string;
  @Prop({ type: String, default: "" }) public legendGuidanceHigh!: string;
  @Prop({ default: () => [] }) public values!: {
    guidanceValue: number;
    value: number;
  }[];
  @Prop({ type: Number }) public value!: number;
  @Prop({ type: Boolean, default: false }) public showYScale!: boolean;

  public legendHeight = 18;
  public selectedValueIndex!: number;
  public guidanceValues!: number[];
  public scales!: {
    x: ScaleBand<string>;
    y: ScaleLinear<number, number>;
    maxY: number;
  };
}

@Component<GuidedSliderClass>({
  computed: {
    selectedValue: {
      set(i) {
        this.$emit("input", +i.toFixed(2));
      },
      get() {
        return this.value;
      }
    },
    selectedValueIndex: {
      set(i) {
        this.$emit("input", this.values[i].value);
      },
      get() {
        return this.values.findIndex(v => v.value === this.value);
      }
    },
    dataValues() {
      return this.values.map(x => x.value);
    },
    guidanceValues() {
      return this.values.map(x => x.guidanceValue);
    },
    scales() {
      const maxY = Math.max(...this.guidanceValues);
      const y = scaleLinear()
        .range([this.height - this.legendHeight, 0])
        .domain([0, maxY]);
      const x = scaleBand()
        .range([0, this.width])
        .domain(this.values.map(x => String(x.value)));
      return { y, x, maxY };
    }
  }
})
export default class GuidedSlider extends GuidedSliderClass {
  get rangeInputBubbleWidthPlusPadding() {
    switch (navigator.platform) {
      case "Win32":
        return 12;
      case "MacIntel":
        return 18;
      default:
        return 18;
    }
  }

  drawAxis() {
    const xScaleElement = this.$refs.scalex as SVGGElement;

    const tickValues = this.values
      .filter((v, i) =>
        this.ticksBy === "value"
          ? v.value % this.ticksEvery === 0
          : i % this.ticksEvery === 0
      )
      .map(x => String(x.value))
      .concat([String(this.value)]);

    const axisB = axisBottom(this.scales.x as any)
      .tickSize(3)
      .tickValues(tickValues);
    select(xScaleElement)
      .call(axisB as any)
      .call(g =>
        g.attr("transform", `translate(0, ${this.height - this.legendHeight})`)
      );

    if (this.showYScale) {
      const yScaleElement = this.$refs.scaley as SVGElement;
      const axisL = this.allowDirectInput
        ? axisLeft(this.scales.y as any)
            .tickSize(3)
            .tickValues(range(0, this.scales.maxY + 1))
            .tickFormat(format("d") as any)
        : axisLeft(this.scales.y as any)
            .tickSize(3)
            .ticks(3)
            .tickFormat(format(".0") as any);
      select(yScaleElement)
        .call(axisL as any)
        .call(g => g.attr("transform", "translate(-2,0)").attr("font-size", 8));
    }
  }

  updated() {
    this.drawAxis();
  }

  mounted() {
    this.drawAxis();
  }
}
</script>

<style lang="less" scoped>
input {
  width: 100%;
}

.guided-slider {
  margin-bottom: 15px;
}

.description {
  display: flex;
  justify-content: center;
}

.legend {
  display: flex;
  justify-content: space-between;

  &__label {
    color: gray;
    font-size: 10px;
  }
}

.weight {
  fill: darkgray;
  &.selected {
    fill: gray;
  }
}
</style>
