import { useForm } from "@tanstack/react-form";
import type { Club } from "../../types";
import { useSettings } from "../../lib/settingsStore";
import { fromYards, roundForUnit, toYards, unitLabel } from "../../lib/units";

export type ClubFormValues = {
    name: string;
    carryYards: number;
    carrySd: number;
    lateralSd: number;
};

type Props = {
    initial?: Club;
    submitting?: boolean;
    onSubmit: (values: ClubFormValues) => void;
    onCancel: () => void;
};

const MAX_NAME_LENGTH = 60;
const MAX_CARRY = 500;
const MAX_SD = 100;

type Errors = Partial<Record<keyof ClubFormValues, string>>;

export function validate(values: {
    name: string;
    carryYards: string;
    carrySd: string;
    lateralSd: string;
}): { errors: Errors; parsed?: ClubFormValues } {
    const errors: Errors = {};

    const name = values.name.trim();
    if (!name) errors.name = "Required";
    else if (name.length > MAX_NAME_LENGTH)
        errors.name = `Max ${MAX_NAME_LENGTH} characters`;

    const carryYards = Number(values.carryYards);
    if (!Number.isFinite(carryYards) || carryYards <= 0) {
        errors.carryYards = "Must be > 0";
    } else if (carryYards > MAX_CARRY) {
        errors.carryYards = `Max ${MAX_CARRY}`;
    }

    const carrySd = Number(values.carrySd);
    if (!Number.isFinite(carrySd) || carrySd <= 0) {
        errors.carrySd = "Must be > 0";
    } else if (carrySd > MAX_SD) {
        errors.carrySd = `Max ${MAX_SD}`;
    }

    const lateralSd = Number(values.lateralSd);
    if (!Number.isFinite(lateralSd) || lateralSd <= 0) {
        errors.lateralSd = "Must be > 0";
    } else if (lateralSd > MAX_SD) {
        errors.lateralSd = `Max ${MAX_SD}`;
    }

    if (Object.keys(errors).length > 0) return { errors };
    return { errors, parsed: { name, carryYards, carrySd, lateralSd } };
}

function nameValidator(value: string): string | undefined {
    const v = value.trim();
    if (!v) return "Required";
    if (v.length > MAX_NAME_LENGTH) return `Max ${MAX_NAME_LENGTH} characters`;
    return undefined;
}

function makePositiveValidator(max: number) {
    return (value: number): string | undefined => {
        if (!Number.isFinite(value) || value <= 0) return "Must be > 0";
        if (value > max) return `Max ${max}`;
        return undefined;
    };
}

export function ClubForm({ initial, submitting, onSubmit, onCancel }: Props) {
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);

    const form = useForm({
        defaultValues: {
            name: initial?.name ?? "",
            carry: initial ? roundForUnit(fromYards(initial.carryYards, unit), unit) : 0,
            carrySd: initial ? roundForUnit(fromYards(initial.carrySd, unit), unit) : 0,
            lateralSd: initial ? roundForUnit(fromYards(initial.lateralSd, unit), unit) : 0,
        },
        onSubmit: ({ value }) => {
            onSubmit({
                name: value.name.trim(),
                carryYards: toYards(value.carry, unit),
                carrySd: toYards(value.carrySd, unit),
                lateralSd: toYards(value.lateralSd, unit),
            });
        },
    });

    const carryMax = roundForUnit(fromYards(MAX_CARRY, unit), unit);
    const sdMax = roundForUnit(fromYards(MAX_SD, unit), unit);

    return (
        <form
            onSubmit={(e) => {
                e.preventDefault();
                form.handleSubmit();
            }}
            className="rounded-2xl border border-[#1a2419]/10 bg-white/60 p-5 space-y-4"
        >
            <form.Field
                name="name"
                validators={{
                    onChange: ({ value }) => nameValidator(value),
                    onSubmit: ({ value }) => nameValidator(value),
                }}
            >
                {(field) => (
                    <Field
                        label="Name"
                        error={fieldError(field)}
                        input={
                            <input
                                type="text"
                                value={field.state.value}
                                onChange={(e) => field.handleChange(e.target.value)}
                                onBlur={field.handleBlur}
                                placeholder="7 Iron"
                                className="w-full px-3 py-2 rounded-lg border border-[#1a2419]/15 bg-white focus:outline-none focus:border-[#1a2419]/40"
                            />
                        }
                    />
                )}
            </form.Field>

            <div className="grid grid-cols-3 gap-3">
                <form.Field
                    name="carry"
                    validators={{
                        onChange: ({ value }) =>
                            makePositiveValidator(carryMax)(value),
                        onSubmit: ({ value }) =>
                            makePositiveValidator(carryMax)(value),
                    }}
                >
                    {(field) => (
                        <NumberField
                            label={`Carry (${u})`}
                            error={fieldError(field)}
                            value={field.state.value}
                            onChange={field.handleChange}
                            onBlur={field.handleBlur}
                        />
                    )}
                </form.Field>

                <form.Field
                    name="carrySd"
                    validators={{
                        onChange: ({ value }) => makePositiveValidator(sdMax)(value),
                        onSubmit: ({ value }) => makePositiveValidator(sdMax)(value),
                    }}
                >
                    {(field) => (
                        <NumberField
                            label={`Carry SD (${u})`}
                            error={fieldError(field)}
                            value={field.state.value}
                            onChange={field.handleChange}
                            onBlur={field.handleBlur}
                        />
                    )}
                </form.Field>

                <form.Field
                    name="lateralSd"
                    validators={{
                        onChange: ({ value }) => makePositiveValidator(sdMax)(value),
                        onSubmit: ({ value }) => makePositiveValidator(sdMax)(value),
                    }}
                >
                    {(field) => (
                        <NumberField
                            label={`Lateral SD (${u})`}
                            error={fieldError(field)}
                            value={field.state.value}
                            onChange={field.handleChange}
                            onBlur={field.handleBlur}
                        />
                    )}
                </form.Field>
            </div>

            <div className="flex justify-end gap-2 pt-2">
                <button
                    type="button"
                    onClick={onCancel}
                    className="px-4 py-2 rounded-full text-sm text-[#1a2419]/70 hover:text-[#1a2419]"
                >
                    Cancel
                </button>
                <form.Subscribe
                    selector={(s) => [s.canSubmit, s.isSubmitting] as const}
                >
                    {([canSubmit, isSubmitting]) => (
                        <button
                            type="submit"
                            disabled={!canSubmit || submitting || isSubmitting}
                            className="px-4 py-2 rounded-full text-sm bg-[#1a2419] text-[#f4efe3] disabled:opacity-50"
                        >
                            {initial ? "Save" : "Add club"}
                        </button>
                    )}
                </form.Subscribe>
            </div>
        </form>
    );
}

type FieldLike = {
    state: { meta: { errors: ReadonlyArray<unknown>; isTouched: boolean } };
};

function fieldError(field: FieldLike): string | undefined {
    if (!field.state.meta.isTouched) return undefined;
    const first = field.state.meta.errors[0];
    return typeof first === "string" ? first : undefined;
}

function Field({
    label,
    input,
    error,
}: {
    label: string;
    input: React.ReactNode;
    error?: string;
}) {
    return (
        <label className="block">
            <div className="text-[10px] tracking-[0.18em] uppercase text-[#1a2419]/50 mb-1">
                {label}
            </div>
            {input}
            {error && (
                <div className="mt-1 text-xs text-red-700">{error}</div>
            )}
        </label>
    );
}

function NumberField({
    label,
    value,
    error,
    onChange,
    onBlur,
}: {
    label: string;
    value: number;
    error?: string;
    onChange: (n: number) => void;
    onBlur: () => void;
}) {
    return (
        <Field
            label={label}
            error={error}
            input={
                <input
                    type="number"
                    inputMode="decimal"
                    step="0.1"
                    value={value}
                    onChange={(e) => {
                        const n = Number(e.target.value);
                        onChange(Number.isFinite(n) ? n : 0);
                    }}
                    onBlur={onBlur}
                    className="w-full px-3 py-2 rounded-lg border border-[#1a2419]/15 bg-white focus:outline-none focus:border-[#1a2419]/40"
                />
            }
        />
    );
}
