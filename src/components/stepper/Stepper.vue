<template>
  <div>
    <slot></slot>
    <div style="margin-top: 10px;">
      <button class="button" v-bind:disabled="!canPrev" v-on:click="previous">
        {{ atFirstStep ? "Cancel" : "Back" }}
      </button>
      <button class="button" v-on:click="next">
        {{ atLastStep ? "Submit" : "Next" }}
      </button>
    </div>
  </div>
</template>

<script lang="ts">
import { Vue, Component, Prop } from "vue-property-decorator";

class StepperClass extends Vue {
  public numSteps!: number;
  public atFirstStep!: boolean;
  public atLastStep!: boolean;
  public setCurrentStep!: (step: number) => void;
  public getCurrentStep!: () => number;
  public registerStep!: (step: number) => void;
}

@Component<StepperClass>({
  methods: {
    registerStep(step: number) {
      const idx = this.$data.steps.indexOf(step);
      if (idx === -1) {
        this.$data.steps = [...this.$data.steps, step];
      }
    },
    getCurrentStep() {
      return this.$data.currentStep;
    },
    setCurrentStep(step: number) {
      this.$data.currentStep = step;
      this.$emit("update-step", this.$data.currentStep);
    },
    previous() {
      if (this.atFirstStep) {
        this.$emit("abort");
      } else {
        this.setCurrentStep(this.$data.currentStep - 1);
      }
    },
    next() {
      if (!this.atLastStep) {
        this.setCurrentStep(this.$data.currentStep + 1);
      } else {
        this.$emit("finish");
      }
    }
  },
  computed: {
    numSteps() {
      return this.$data.steps.length;
    },
    atFirstStep() {
      return this.$data.currentStep === 0;
    },
    atLastStep() {
      return this.$data.currentStep === this.numSteps - 1;
    },
    canPrev() {
      return true;
    },
    canNext() {
      return this.$data.currentStep + 1 < this.numSteps;
    }
  },
  provide: function() {
    return {
      getCurrentStep: this.getCurrentStep,
      setCurrentStep: this.setCurrentStep,
      registerStep: this.registerStep
    };
  },
  data: function() {
    return {
      steps: [],
      currentStep: 0
    };
  }
})
export default class Stepper extends StepperClass {}
</script>

<style lang="less" scoped>
.button {
  + .button {
    margin-left: 5px;
  }
}
</style>
