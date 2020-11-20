import {
  add as dfnAdd,
  Duration as dfnDuration,
  addMilliseconds as dfnAddMS
} from "date-fns";

type Duration = dfnDuration & {
  weeks?: number | undefined;
  milliseconds?: number | undefined;
};
type DurationName = keyof Duration;

// Like add from date-fns, but can deal with weeks
export function add(d: Date, durations: Duration) {
  const durationNames: DurationName[] = Object.keys(
    durations
  ) as DurationName[];
  if (durationNames.length !== 1) {
    throw new Error("Nope sorry");
  }
  const durationName = durationNames[0];
  if (durationName === "weeks") {
    return dfnAdd(d, { days: 7 * (durations[durationName] || 0) });
  }
  if (durationName === "milliseconds") {
    return dfnAddMS(d, durations[durationName] || 0);
  }
  return dfnAdd(d, durations);
}
