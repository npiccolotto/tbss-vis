<template>
  <svg
    v-bind:width="size + 2 + margin[3] + margin[1]"
    v-bind:height="size + 2 + margin[0] + margin[2]"
  >
    <rect
      v-bind:x="margin[3]"
      v-bind:y="margin[0]"
      fill="white"
      v-bind:height="matrix.length * cellSize + 2"
      v-bind:width="matrix[0].length * cellSize + 2"
      stroke="black"
      v-bind:stroke-width="showBorder ? 1 : 0"
    />
    <g
      v-bind:transform="
        'translate(' + margin[3] / 2 + ',' + margin[0] / 2 + ')'
      "
    >
      <circle
        v-bind:fill="color"
        cx="0"
        cy="0"
        v-bind:r="Math.min(margin[3], margin[0]) / 4"
      />
    </g>

    <g
      v-for="(row, rowidx) in matrix"
      v-bind:key="rowidx"
      transform="translate(1,1)"
    >
      <g v-for="(val, colidx) in row" v-bind:key="rowidx + '/' + colidx">
        <circle
          v-if="val.shape === 'circle'"
          v-bind:fill="val.color"
          v-bind:r="cellSize / 4"
          v-bind:cx="margin[3] + colidx * cellSize + cellSize / 2"
          v-bind:cy="margin[0] + rowidx * cellSize + cellSize / 2"
        />
        <g v-else>
          <rect
            v-on:click="handleClick(rowidx, colidx)"
            v-bind:x="
              margin[3] +
                colidx * cellSize +
                (val.stroke ? val.stroke.width / 2 : 0)
            "
            v-bind:y="
              margin[0] +
                rowidx * cellSize +
                (val.stroke ? val.stroke.width / 2 : 0)
            "
            v-bind:fill="val.color"
            v-bind:width="cellSize - (val.stroke ? val.stroke.width : 0)"
            v-bind:height="cellSize - (val.stroke ? val.stroke.width : 0)"
            v-bind:stroke="val.stroke ? val.stroke.color : 'none'"
            v-bind:stroke-width="val.stroke ? val.stroke.width : 0"
            v-bind:style="{
              color: color
            }"
            v-bind:class="{
              heatmap: true,
              interactive: cellsInteractive,
              selected:
                cellsInteractive &&
                selection.some(s => s[0] === rowidx && s[1] === colidx)
            }"
          >
            <title>
              {{ val.title }}
            </title>
          </rect>
          <rect
            v-if="
              cellsInteractive &&
                selection.some(s => s[0] === rowidx && s[1] === colidx)
            "
            v-on:click="handleClick(rowidx, colidx)"
            v-bind:x="
              margin[3] +
                colidx * cellSize +
                (val.stroke ? val.stroke.width / 2 : 0) +
                cellSize / 4
            "
            v-bind:y="
              margin[0] +
                rowidx * cellSize +
                (val.stroke ? val.stroke.width / 2 : 0) +
                cellSize / 4
            "
            v-bind:fill="color"
            v-bind:width="(cellSize - (val.stroke ? val.stroke.width : 0)) / 2"
            v-bind:height="(cellSize - (val.stroke ? val.stroke.width : 0)) / 2"
            v-bind:stroke="val.stroke ? val.stroke.color : 'none'"
            v-bind:stroke-width="val.stroke ? val.stroke.width : 0"
            class="selection-marker"
            v-bind:style="{
              color: color
            }"
          ></rect>
        </g>
      </g>
    </g>
    <g>
      <text
        class="label"
        v-for="(rowLabel, i) in rowLabels"
        v-bind:key="rowLabel"
        v-bind:data-row="rowLabel"
        x="10"
        v-bind:y="margin[3] + (i + 1) * cellSize - cellSize / 4"
        v-bind:style="{
          color: color
        }"
        v-on:click="unselectRow(i)"
        v-bind:class="{ label: true, selected: selectedRows.indexOf(i) >= 0 }"
      >
        {{ rowLabel }}
      </text>
    </g>
    <g
      v-bind:transform="
        'rotate(-90)translate(' +
          (-margin[0] - 5) +
          ',' +
          (margin[3] - cellSize / 4) +
          ')'
      "
    >
      <text
        v-bind:style="{
          color: color
        }"
        v-bind:class="{ label: true, selected: selectedCols.indexOf(i) >= 0 }"
        v-for="(colLabel, i) in colLabels"
        v-bind:key="colLabel"
        v-bind:data-col="colLabel"
        x="10"
        v-on:click="unselectCol(i)"
        v-bind:y="(i + 1) * cellSize"
      >
        {{ colLabel }}
      </text>
    </g>
  </svg>
</template>

<script lang="ts">
import { Vue, Component, Prop } from "vue-property-decorator";
import { extent } from "d3-array";

export type MatrixValue = {
  title: string;
  color: string;
  value: number;
  shape: "rect" | "circle";
};

class MatrixClass extends Vue {
  public selection!: [number, number][];
}

@Component<MatrixClass>({
  computed: {
    cellSize() {
      return this.$props.size / this.$props.matrix.length;
    },
    selectedCols() {
      return [...new Set(this.selection.map(([row, col]) => col))];
    },
    selectedRows() {
      return [...new Set(this.selection.map(([row]) => row))];
    }
  }
})
export default class Matrix extends MatrixClass {
  @Prop({ default: () => [] }) public rowLabels!: string[];
  @Prop({ default: () => [] }) public colLabels!: string[];
  @Prop({ default: "" }) public id!: string;
  @Prop({ default: 100 }) public size!: number;
  @Prop({ default: "red" }) public color!: string;
  @Prop({ default: false }) public showBorder!: boolean;
  @Prop({ default: false }) public cellsInteractive!: boolean;
  @Prop({ default: () => [] }) public matrix!: MatrixValue[][];
  @Prop({ default: () => [30, 2, 2, 30] }) public margin!: [
    number,
    number,
    number,
    number
  ];

  public selection: [number, number][] = [];

  handleClick(row: number, col: number) {
    if (!this.cellsInteractive) {
      return;
    }
    const selectedIndex = this.selection.findIndex(
      ([srow, scol]) => srow === row && scol === col
    );
    if (selectedIndex < 0) {
      this.selection = [...this.selection, [row, col]];
    } else {
      this.selection.splice(selectedIndex, 1);
      this.selection = [...this.selection];
    }
    this.$emit("selected", { id: this.id, selection: this.selection });
  }

  unselectRow(row: number) {
    const newSelect = this.selection.filter(([r]) => r !== row);
    this.selection = newSelect;
    this.$emit("selected", { id: this.id, selection: this.selection });
  }

  unselectCol(col: number) {
    const newSelect = this.selection.filter(([, c]) => c !== col);
    this.selection = newSelect;
    this.$emit("selected", { id: this.id, selection: this.selection });
  }
}
</script>

<style lang="less" scoped>
rect.heatmap {
  &.interactive:hover {
    cursor: pointer;
    stroke: currentColor;
    stroke-width: 1px;
  }
}
rect.selection-marker {
  pointer-events: none;
}
text.label {
  font-size: 10px;
  font-family: monospace;
  user-select: none;

  &.selected {
    fill: currentColor;
    cursor: pointer;
    font-weight: 700;
  }
}
</style>
