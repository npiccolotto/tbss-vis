<template>
  <div>
    <Stepper v-on:abort="handleStepperAbort" v-on:finish="handleStepperFinish">
      <Step v-bind:step="1"
        ><div>
          <h5>Weight input</h5>
          <GuidedSlider
            v-model="b"
            v-bind:allowDirectInput="true"
            v-bind:values="bValuesWithGuidance"
            v-bind:ticksEvery="10"
            ticksBy="index"
            legendValue="Weight"
            v-bind:showYScale="true"
            legendGuidance="How often a weight was chosen previously"
            legendGuidanceLow="← use k2 (vSOBI) more"
            legendGuidanceHigh="use k1 (SOBI) more →"
          />
          <!-- legendGuidanceLow="only quadratic autocorrelation"
            legendGuidanceHigh="only linear autocorrelation"-->
        </div>
      </Step>
      <Step v-bind:step="2">
        <div v-if="b == 0">
          Selected weight renders k1 lag set unused, you can skip it.
        </div>
        <div v-else>
          <h5>k1 Lag selection</h5>
          <LagInput
            v-bind:selectedLags="lagsetk1"
            v-on:select-lag="handleLag1Select"
            lagType="k1"
          /></div
      ></Step>
      <Step v-bind:step="3">
        <div v-if="b == 1">
          Selected weight renders k2 lag set unused, you can skip it.
        </div>
        <div v-else>
          <h5>k2 Lag selection</h5>
          <LagInput
            v-bind:selectedLags="lagsetk2"
            v-on:select-lag="handleLag2Select"
            lagType="k2"
          /></div
      ></Step>
    </Stepper>
  </div>
</template>

<script lang="ts">
import { Vue, Component } from "vue-property-decorator";
import LagInput from "@/components/parameter-input/LagInput.vue";
import GuidedSlider from "@/components/parameter-input/GuidedSlider.vue";
import Stepper from "@/components/stepper/Stepper.vue";
import Step from "@/components/stepper/Step.vue";
import range from "lodash-es/range";
import { histogram } from "d3-array";

@Component({
  components: { LagInput, GuidedSlider, Stepper, Step },
  data: function() {
    return { b: this.$store.state.currentParameters.b };
  },
  computed: {
    lagsetk1() {
      return this.$store.state.currentParameters.k1;
    },
    lagsetk2() {
      return this.$store.state.currentParameters.k2;
    },
    bValuesWithGuidance() {
      const h = histogram()
        .domain([0, 1])
        .thresholds(
          range(101)
            .map(x => x * 0.01)
            .map(x => Math.round(x * 1000) / 1000)
        );
      const guidance = h(this.$store.getters.previousParameterValues("b")).map(
        (bin, i) => ({
          guidanceValue: bin.length,
          value: i / 100
        })
      );
      return guidance;
    }
  },
  watch: {
    b: function(n) {
      this.$store.dispatch("setCurrentParameter", {
        variable: "b",
        value: n
      });
    }
  }
})
export default class ParameterInput extends Vue {
  handleLag1Select(lags: number[]) {
    this.$store.dispatch("setCurrentParameter", {
      variable: "k1",
      value: lags
    });
  }

  handleLag2Select(lags: number[]) {
    this.$store.dispatch("setCurrentParameter", {
      variable: "k2",
      value: lags
    });
  }
  handleStepperAbort() {
    this.$store.dispatch("resetCurrentParameters");
    this.$router.push("/");
  }
  handleStepperFinish() {
    this.$store.dispatch("submitCurrentParameters");
    this.$router.push("/");
  }
}
</script>
