<template>
  <div v-if="step === currentStep + 1">
    <slot></slot>
  </div>
</template>

<script lang="ts">
import { Vue, Component, Prop } from "vue-property-decorator";

class StepClass extends Vue {
  // Injected from Stepper
  public setCurrentStep!: (step: number) => void;
  public getCurrentStep!: () => number;
  public registerStep!: (step: number) => void;
}

@Component<StepClass>({
  computed: {
    currentStep: {
      get: function() {
        return this.getCurrentStep();
      },
      set: function(d) {
        this.setCurrentStep(d);
      }
    }
  },
  inject: ["setCurrentStep", "getCurrentStep", "registerStep"]
})
export default class Step extends StepClass {
  @Prop({ type: Number, required: true }) private step!: number;

  mounted() {
    this.registerStep(this.$props.step);
  }
}
</script>

<style lang="less" scoped></style>
