/* @ds-bundle: {"format":4,"namespace":"GymTrackerDesignSystem_9b15a7","components":[{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"IconChip","sourcePath":"components/core/IconChip.jsx"},{"name":"SectionLabel","sourcePath":"components/core/SectionLabel.jsx"},{"name":"SearchField","sourcePath":"components/forms/SearchField.jsx"},{"name":"SegmentedControl","sourcePath":"components/forms/SegmentedControl.jsx"},{"name":"SetInput","sourcePath":"components/forms/SetInput.jsx"},{"name":"StepperRow","sourcePath":"components/forms/StepperRow.jsx"},{"name":"HistoryRow","sourcePath":"components/lists/HistoryRow.jsx"},{"name":"ListRow","sourcePath":"components/lists/ListRow.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"},{"name":"ActivityHeatmap","sourcePath":"components/progress/ActivityHeatmap.jsx"},{"name":"ComparisonPanel","sourcePath":"components/progress/ComparisonPanel.jsx"},{"name":"RecommendationCard","sourcePath":"components/progress/RecommendationCard.jsx"},{"name":"StatusRow","sourcePath":"components/progress/StatusRow.jsx"},{"name":"UpcomingCalendar","sourcePath":"components/progress/UpcomingCalendar.jsx"},{"name":"ExerciseCard","sourcePath":"components/workout/ExerciseCard.jsx"},{"name":"RestTimer","sourcePath":"components/workout/RestTimer.jsx"},{"name":"SessionHeader","sourcePath":"components/workout/SessionHeader.jsx"},{"name":"SetRow","sourcePath":"components/workout/SetRow.jsx"}],"sourceHashes":{"components/core/Badge.jsx":"0e2288e15af2","components/core/Button.jsx":"fb9bd73b80a6","components/core/Card.jsx":"07938af76d5f","components/core/Icon.jsx":"042616efc082","components/core/IconChip.jsx":"6afd854ea1cb","components/core/SectionLabel.jsx":"39ee400466d3","components/forms/SearchField.jsx":"f978a783105f","components/forms/SegmentedControl.jsx":"9dde06432002","components/forms/SetInput.jsx":"ae9ad9964c52","components/forms/StepperRow.jsx":"3cc5df66c251","components/lists/HistoryRow.jsx":"fa1fb2bd61e7","components/lists/ListRow.jsx":"c5f61e3914b6","components/navigation/TabBar.jsx":"9c9dab69ec3b","components/progress/ActivityHeatmap.jsx":"0648f63c9194","components/progress/ComparisonPanel.jsx":"2710644d6c33","components/progress/RecommendationCard.jsx":"011ce3b93b4b","components/progress/StatusRow.jsx":"b9b45836aeef","components/progress/UpcomingCalendar.jsx":"5294016d131c","components/workout/ExerciseCard.jsx":"704a79651421","components/workout/RestTimer.jsx":"1b9dbbd731d0","components/workout/SessionHeader.jsx":"3138fa06d941","components/workout/SetRow.jsx":"f8b8012a005e","ui_kits/ios-app/ActiveWorkoutScreen.jsx":"7c061adab315","ui_kits/ios-app/HistoryScreen.jsx":"b58625df8597","ui_kits/ios-app/HomeScreen.jsx":"94f09a05385f","ui_kits/ios-app/LibraryScreen.jsx":"444f5c824c3f","ui_kits/ios-app/chrome.jsx":"0d12e61aca4c"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.GymTrackerDesignSystem_9b15a7 = window.GymTrackerDesignSystem_9b15a7 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Badge.jsx
try { (() => {
const COLORS = {
  primary: "var(--gym-primary)",
  secondary: "var(--gym-secondary)",
  accent: "var(--gym-accent)",
  neutral: "var(--gym-text-subdued)"
};
const TINTS = {
  primary: "var(--gym-primary-surface)",
  secondary: "var(--gym-secondary-surface)",
  accent: "var(--gym-accent-surface)",
  neutral: "var(--gym-row-surface)"
};
function Badge({
  color = "accent",
  variant = "tint",
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      font: "var(--type-caption2-bold)",
      color: COLORS[color],
      background: variant === "card" ? "rgba(255,252,247,0.72)" : TINTS[color],
      borderRadius: "var(--radius-pill)",
      padding: "3px 8px",
      whiteSpace: "nowrap",
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
const VARIANTS = {
  standard: {
    background: "var(--surface-card)",
    border: "var(--border-hairline)",
    boxShadow: "var(--shadow-card)"
  },
  elevated: {
    background: "var(--gym-card-elevated)",
    border: "var(--border-hairline)",
    boxShadow: "var(--shadow-card)"
  },
  outlined: {
    background: "var(--surface-card)",
    border: "var(--border-outline)",
    boxShadow: "var(--shadow-card)"
  },
  current: {
    background: "var(--gym-current-set-surface)",
    border: "var(--border-focus)"
  },
  completed: {
    background: "var(--gym-secondary-surface)",
    border: "var(--border-hairline)"
  },
  accent: {
    background: "var(--gym-accent-surface)",
    border: "var(--border-hairline)"
  },
  muted: {
    background: "var(--gym-muted-surface)",
    border: "none"
  }
};
const RADII = {
  card: "var(--radius-card)",
  section: "var(--radius-section)",
  large: "var(--radius-large)"
};
function Card({
  variant = "standard",
  radius = "card",
  padding = "16px",
  onClick,
  children,
  style
}) {
  const Tag = onClick ? "button" : "div";
  return /*#__PURE__*/React.createElement(Tag, {
    className: onClick ? "gym-press" : undefined,
    onClick: onClick,
    style: {
      display: "block",
      width: "100%",
      textAlign: "left",
      font: "inherit",
      color: "var(--gym-text)",
      cursor: onClick ? "pointer" : undefined,
      borderRadius: RADII[radius] || radius,
      padding,
      boxSizing: "border-box",
      ...VARIANTS[variant],
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
const MAP = {
  home: "home",
  folders: "folder",
  history: "history",
  settings: "settings",
  plan: "calendar_month",
  planAdd: "edit_calendar",
  reschedule: "event_repeat",
  minimize: "keyboard_arrow_down",
  chevronLeft: "chevron_left",
  chevronRight: "chevron_right",
  chevronDown: "keyboard_arrow_down",
  picker: "unfold_more",
  plus: "add",
  minus: "remove",
  trash: "delete",
  copy: "content_copy",
  ellipsis: "more_horiz",
  edit: "edit",
  lock: "lock",
  save: "download_for_offline",
  filters: "filter_list",
  play: "play_arrow",
  pause: "pause",
  skip: "fast_forward",
  reset: "replay",
  archive: "archive",
  export: "ios_share",
  import: "download",
  checkmark: "check",
  checkmarkCircle: "check_circle",
  circle: "radio_button_unchecked",
  circleFill: "circle",
  circleDashed: "pending",
  info: "info",
  warning: "warning",
  number: "tag",
  favorite: "star",
  workout: "fitness_center",
  timer: "timer",
  chart: "show_chart",
  progression: "trending_up",
  trophy: "trophy",
  plateCalculator: "apps",
  warmup: "local_fire_department",
  search: "search",
  bolt: "bolt",
  stack: "stacks",
  nutrition: "restaurant"
};
let injected = false;
function ensureFont() {
  if (injected || typeof document === "undefined") return;
  if (!document.querySelector("link[data-gym-icons]")) {
    const l = document.createElement("link");
    l.rel = "stylesheet";
    l.setAttribute("data-gym-icons", "");
    l.href = "https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,300..700,0..1,-50..200&display=block";
    document.head.appendChild(l);
  }
  injected = true;
}
function Icon({
  name,
  size = 20,
  filled = true,
  weight = 500,
  color,
  style,
  className
}) {
  ensureFont();
  const opsz = Math.max(20, Math.min(48, size));
  return /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded" + (className ? " " + className : ""),
    "aria-hidden": "true",
    style: {
      fontFamily: "Material Symbols Rounded",
      fontSize: size,
      lineHeight: 1,
      color,
      display: "inline-block",
      userSelect: "none",
      fontVariationSettings: "\u0027FILL\u0027 " + (filled ? 1 : 0) + ", \u0027wght\u0027 " + weight + ", \u0027opsz\u0027 " + opsz,
      ...style
    }
  }, MAP[name] || name);
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
const COLORS = {
  primary: "var(--gym-primary)",
  secondary: "var(--gym-secondary)",
  accent: "var(--gym-accent)",
  destructive: "var(--gym-destructive)"
};
const TINTS = {
  primary: "var(--gym-primary-tint)",
  secondary: "var(--gym-secondary-tint)",
  accent: "var(--gym-accent-tint)",
  destructive: "rgba(255,59,48,0.12)"
};
function Button({
  variant = "primary",
  color = "primary",
  icon,
  trailingIcon,
  children,
  fullWidth,
  disabled,
  onClick,
  style
}) {
  const c = COLORS[color] || color;
  const base = {
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "8px",
    border: "none",
    cursor: disabled ? "default" : "pointer",
    fontFamily: "var(--font-body)",
    opacity: disabled ? 0.45 : 1,
    whiteSpace: "nowrap"
  };
  const variants = {
    primary: {
      font: "var(--type-subheadline-bold)",
      color: "#fff",
      background: c,
      borderRadius: "var(--radius-pill)",
      padding: "12px 20px"
    },
    prominent: {
      font: "var(--type-headline)",
      color: "#fff",
      background: c,
      borderRadius: "var(--radius-button)",
      padding: "17px 20px",
      width: "100%"
    },
    bordered: {
      font: "var(--type-subheadline-semibold)",
      color: c,
      background: TINTS[color] || "var(--gym-row-surface)",
      borderRadius: "var(--radius-medium)",
      padding: "8px 14px",
      minHeight: "36px"
    },
    text: {
      font: "var(--type-subheadline-semibold)",
      color: c,
      background: "none",
      padding: "6px 4px",
      minHeight: "32px"
    }
  };
  return /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    disabled: disabled,
    onClick: onClick,
    style: {
      ...base,
      ...variants[variant],
      ...(fullWidth ? {
        width: "100%"
      } : {}),
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: variant === "prominent" ? 18 : 16
  }), children, trailingIcon && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: trailingIcon,
    size: 14,
    weight: 700
  }));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/IconChip.jsx
try { (() => {
const COLORS = {
  primary: "var(--gym-primary)",
  secondary: "var(--gym-secondary)",
  accent: "var(--gym-accent)",
  neutral: "var(--gym-text)"
};
const TINTS = {
  primary: "var(--gym-primary-tint)",
  secondary: "var(--gym-secondary-tint)",
  accent: "var(--gym-accent-tint)",
  neutral: "rgba(39,38,53,0.06)"
};
const SURFACES = {
  primary: "var(--gym-primary-surface)",
  secondary: "var(--gym-secondary-surface)",
  accent: "var(--gym-accent-surface)",
  neutral: "var(--gym-row-surface)"
};
function IconChip({
  icon,
  color = "primary",
  shape = "circle",
  size = 38,
  surface = false,
  iconSize,
  filled = true,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: size,
      height: size,
      flex: "none",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      borderRadius: shape === "circle" ? "50%" : "var(--radius-medium)",
      background: surface ? SURFACES[color] : TINTS[color],
      color: COLORS[color],
      ...style
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: iconSize || Math.round(size * 0.47),
    filled: filled
  }));
}
Object.assign(__ds_scope, { IconChip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconChip.jsx", error: String((e && e.message) || e) }); }

// components/core/SectionLabel.jsx
try { (() => {
function SectionLabel({
  children,
  icon,
  iconColor = "var(--gym-secondary)",
  detail,
  trailing,
  color = "var(--gym-text-subdued)",
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "8px",
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 13,
    weight: 700,
    color: iconColor
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption-bold)",
      letterSpacing: "var(--tracking-label)",
      color,
      textTransform: "uppercase"
    }
  }, children), detail && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)"
    }
  }, detail), trailing && /*#__PURE__*/React.createElement("div", {
    style: {
      marginLeft: "auto"
    }
  }, trailing));
}
Object.assign(__ds_scope, { SectionLabel });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/SectionLabel.jsx", error: String((e && e.message) || e) }); }

// components/forms/SearchField.jsx
try { (() => {
function SearchField({
  value,
  onChange,
  placeholder = "Search your library",
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "8px",
      height: "46px",
      padding: "0 12px",
      background: "var(--surface-card)",
      borderRadius: "14px",
      boxSizing: "border-box",
      ...style
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "search",
    size: 18,
    filled: false,
    color: "var(--gym-text-subdued)"
  }), /*#__PURE__*/React.createElement("input", {
    value: value,
    onChange: e => onChange && onChange(e.target.value),
    placeholder: placeholder,
    style: {
      flex: 1,
      border: "none",
      outline: "none",
      background: "none",
      font: "var(--type-body)",
      color: "var(--gym-text)"
    }
  }));
}
Object.assign(__ds_scope, { SearchField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/SearchField.jsx", error: String((e && e.message) || e) }); }

// components/forms/SegmentedControl.jsx
try { (() => {
function SegmentedControl({
  options,
  value,
  onChange,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      background: "rgba(39,38,53,0.08)",
      borderRadius: "var(--radius-pill)",
      padding: "2px",
      ...style
    }
  }, options.map(opt => {
    const key = typeof opt === "string" ? opt : opt.value;
    const label = typeof opt === "string" ? opt : opt.label;
    const active = key === value;
    return /*#__PURE__*/React.createElement("button", {
      key: key,
      onClick: () => onChange && onChange(key),
      style: {
        flex: 1,
        border: "none",
        cursor: "pointer",
        font: active ? "var(--type-subheadline-semibold)" : "var(--type-subheadline)",
        color: "var(--gym-text)",
        background: active ? "#fff" : "none",
        borderRadius: "var(--radius-pill)",
        padding: "8px 10px",
        boxShadow: active ? "0 2px 6px rgba(39,38,53,0.10)" : "none",
        transition: "background var(--motion-compact)",
        whiteSpace: "nowrap"
      }
    }, label);
  }));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/forms/SetInput.jsx
try { (() => {
function SetInput({
  value,
  onChange,
  width = "100%",
  disabled,
  style
}) {
  return /*#__PURE__*/React.createElement("input", {
    inputMode: "decimal",
    value: value,
    disabled: disabled,
    onChange: e => onChange && onChange(e.target.value),
    style: {
      width,
      boxSizing: "border-box",
      border: "none",
      outline: "none",
      textAlign: "center",
      font: "600 22px var(--font-body)",
      fontVariantNumeric: "tabular-nums",
      color: "var(--gym-text)",
      background: "var(--surface-card)",
      borderRadius: "var(--radius-medium)",
      padding: "12px 8px",
      opacity: disabled ? 0.6 : 1,
      ...style
    }
  });
}
Object.assign(__ds_scope, { SetInput });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/SetInput.jsx", error: String((e && e.message) || e) }); }

// components/forms/StepperRow.jsx
try { (() => {
function StepperRow({
  label,
  variant = "stepper",
  value,
  on,
  onIncrement,
  onDecrement,
  onToggle,
  onPress,
  last,
  style
}) {
  const row = {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: "12px",
    padding: "16px 16px",
    borderBottom: last ? "none" : "1px solid var(--gym-hairline,rgba(39,38,53,0.08))",
    ...style
  };
  const lbl = /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-body)",
      color: "var(--gym-text)"
    }
  }, label, variant === "stepper" && value !== undefined ? ": " + value : "");
  if (variant === "toggle") {
    return /*#__PURE__*/React.createElement("div", {
      style: row
    }, lbl, /*#__PURE__*/React.createElement("button", {
      className: "gym-press",
      role: "switch",
      "aria-checked": !!on,
      onClick: () => onToggle && onToggle(!on),
      style: {
        width: "51px",
        height: "31px",
        borderRadius: "999px",
        border: "none",
        padding: "2px",
        background: on ? "var(--gym-secondary)" : "rgba(39,38,53,0.18)",
        display: "flex",
        justifyContent: on ? "flex-end" : "flex-start",
        cursor: "pointer",
        transition: "background .15s"
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        width: "27px",
        height: "27px",
        borderRadius: "50%",
        background: "#fff",
        boxShadow: "0 1px 3px rgba(0,0,0,0.2)"
      }
    })));
  }
  if (variant === "picker") {
    return /*#__PURE__*/React.createElement("button", {
      className: "gym-press",
      onClick: onPress,
      style: {
        ...row,
        width: "100%",
        background: "none",
        border: "none",
        borderBottom: row.borderBottom,
        textAlign: "left",
        cursor: "pointer",
        font: "inherit"
      }
    }, lbl, /*#__PURE__*/React.createElement("span", {
      style: {
        display: "flex",
        alignItems: "center",
        gap: "6px",
        font: "var(--type-body)",
        color: "var(--gym-text-subdued)"
      }
    }, value, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "picker",
      size: 17,
      color: "var(--gym-text-subdued)"
    })));
  }
  return /*#__PURE__*/React.createElement("div", {
    style: row
  }, lbl, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      background: "var(--gym-fill-secondary,rgba(39,38,53,0.06))",
      borderRadius: "999px"
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    "aria-label": "Decrease",
    onClick: onDecrement,
    style: {
      width: "52px",
      height: "38px",
      background: "none",
      border: "none",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      cursor: "pointer",
      borderRadius: "999px 0 0 999px"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "minus",
    size: 18,
    color: "var(--gym-text)"
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      width: "1px",
      height: "20px",
      background: "rgba(39,38,53,0.15)"
    }
  }), /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    "aria-label": "Increase",
    onClick: onIncrement,
    style: {
      width: "52px",
      height: "38px",
      background: "none",
      border: "none",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      cursor: "pointer",
      borderRadius: "0 999px 999px 0"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "plus",
    size: 18,
    color: "var(--gym-text)"
  }))));
}
Object.assign(__ds_scope, { StepperRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/StepperRow.jsx", error: String((e && e.message) || e) }); }

// components/lists/HistoryRow.jsx
try { (() => {
function Meta({
  icon,
  children
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "5px",
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 14,
    filled: false,
    color: "var(--gym-text-subdued)"
  }), children);
}
function HistoryRow({
  title,
  date,
  duration,
  exercises,
  sets,
  source,
  onClick,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: onClick ? "gym-press" : undefined,
    onClick: onClick,
    style: {
      display: "flex",
      alignItems: "center",
      gap: "12px",
      padding: "14px 16px",
      background: "var(--surface-card)",
      borderRadius: "var(--radius-large)",
      border: "var(--border-hairline)",
      boxShadow: "var(--shadow-row)",
      cursor: onClick ? "pointer" : undefined,
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      display: "flex",
      flexDirection: "column",
      gap: "8px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: "12px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-headline)",
      overflow: "hidden",
      textOverflow: "ellipsis",
      whiteSpace: "nowrap"
    }
  }, title), /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: "auto",
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)",
      whiteSpace: "nowrap"
    }
  }, date)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "12px",
      flexWrap: "wrap"
    }
  }, duration && /*#__PURE__*/React.createElement(Meta, {
    icon: "timer"
  }, duration), exercises && /*#__PURE__*/React.createElement(Meta, {
    icon: "workout"
  }, exercises), sets && /*#__PURE__*/React.createElement(Meta, {
    icon: "checkmarkCircle"
  }, sets)), source && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "5px",
      font: "var(--type-caption)",
      color: "var(--gym-accent)"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "folders",
    size: 13,
    color: "var(--gym-accent)"
  }), "From ", source)), onClick && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevronRight",
    size: 14,
    weight: 700,
    color: "var(--gym-text-subtle)"
  }));
}
Object.assign(__ds_scope, { HistoryRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/lists/HistoryRow.jsx", error: String((e && e.message) || e) }); }

// components/lists/ListRow.jsx
try { (() => {
function ListRow({
  icon,
  color = "primary",
  surface = true,
  title,
  subtitle,
  count,
  trailing,
  chevron = true,
  card = true,
  size = 42,
  onClick,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: onClick ? "gym-press" : undefined,
    onClick: onClick,
    style: {
      display: "flex",
      alignItems: "center",
      gap: "12px",
      padding: card ? "14px" : "10px 14px",
      background: card ? "var(--surface-card)" : "none",
      border: card ? "var(--border-hairline)" : "none",
      borderRadius: card ? "var(--radius-large)" : "0",
      boxShadow: card ? "var(--shadow-row)" : "none",
      cursor: onClick ? "pointer" : undefined,
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement(__ds_scope.IconChip, {
    icon: icon,
    color: color,
    shape: size >= 40 ? "rounded" : "rounded",
    size: size,
    surface: surface
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body-medium)",
      overflow: "hidden",
      textOverflow: "ellipsis",
      whiteSpace: "nowrap"
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)",
      marginTop: "2px"
    }
  }, subtitle)), count != null && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-subheadline)",
      fontVariantNumeric: "tabular-nums",
      color: "var(--gym-text-subdued)"
    }
  }, count), trailing, chevron && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevronRight",
    size: 14,
    weight: 700,
    color: "var(--gym-text-subtle)"
  }));
}
Object.assign(__ds_scope, { ListRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/lists/ListRow.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
const DEFAULT_TABS = [{
  key: "today",
  icon: "home",
  label: "Today"
}, {
  key: "train",
  icon: "folders",
  label: "Train"
}, {
  key: "nutrition",
  icon: "nutrition",
  label: "Nutrition"
}, {
  key: "progress",
  icon: "history",
  label: "Progress"
}];
function TabBar({
  tabs = DEFAULT_TABS,
  active = "today",
  onChange,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      background: "var(--surface-card)",
      borderRadius: "var(--radius-pill)",
      padding: "6px",
      boxShadow: "0 6px 20px rgba(39,38,53,0.08)",
      ...style
    }
  }, tabs.map(t => {
    const sel = t.key === active;
    return /*#__PURE__*/React.createElement("button", {
      key: t.key,
      onClick: () => onChange && onChange(t.key),
      className: "gym-press",
      style: {
        flex: 1,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: "3px",
        border: "none",
        cursor: "pointer",
        background: sel ? "var(--gym-row-surface)" : "none",
        borderRadius: "var(--radius-pill)",
        padding: "9px 6px"
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: t.icon,
      size: 24,
      color: sel && t.key !== "today" ? "var(--gym-primary)" : "var(--gym-text)"
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-caption2-bold)",
        color: sel && t.key !== "today" ? "var(--gym-primary)" : "var(--gym-text)"
      }
    }, t.label));
  }));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// components/progress/ActivityHeatmap.jsx
try { (() => {
const LEVELS = ["var(--gym-row-surface)", "rgba(72,122,108,0.22)", "rgba(72,122,108,0.45)", "rgba(72,122,108,0.72)", "var(--gym-secondary)"];
function ActivityHeatmap({
  weeks = [],
  monthLabels = [],
  title,
  subtitle,
  cell = 11,
  gap = 3,
  legend = true,
  style
}) {
  const step = cell + gap;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--surface-card)",
      border: "var(--border-hairline)",
      borderRadius: "var(--radius-large)",
      boxShadow: "var(--shadow-row)",
      padding: "16px",
      ...style
    }
  }, (title || subtitle) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: "10px",
      marginBottom: "12px"
    }
  }, title && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-headline)"
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)"
    }
  }, subtitle)), /*#__PURE__*/React.createElement("div", {
    style: {
      overflowX: "auto"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      paddingTop: "16px",
      paddingLeft: "30px",
      width: `${30 + weeks.length * step}px`
    }
  }, monthLabels.map((m, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      position: "absolute",
      top: 0,
      left: `${30 + m.week * step}px`,
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)"
    }
  }, m.label)), ["Lun", "Mer", "Ven"].map((d, i) => /*#__PURE__*/React.createElement("span", {
    key: d,
    style: {
      position: "absolute",
      left: 0,
      top: `${16 + i * 2 * step}px`,
      font: "var(--type-caption)",
      color: "var(--gym-text-subtle)",
      lineHeight: `${cell}px`
    }
  }, d)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: `${gap}px`
    }
  }, weeks.map((col, w) => /*#__PURE__*/React.createElement("div", {
    key: w,
    style: {
      display: "flex",
      flexDirection: "column",
      gap: `${gap}px`
    }
  }, col.map((lv, d) => /*#__PURE__*/React.createElement("div", {
    key: d,
    title: lv > 0 ? `${lv} session${lv > 1 ? "s" : ""}` : undefined,
    style: {
      width: `${cell}px`,
      height: `${cell}px`,
      borderRadius: "3px",
      background: LEVELS[Math.max(0, Math.min(4, lv || 0))]
    }
  }))))))), legend && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "4px",
      justifyContent: "flex-end",
      marginTop: "10px",
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)"
    }
  }, "Moins ", LEVELS.map((c, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      width: "10px",
      height: "10px",
      borderRadius: "3px",
      background: c,
      display: "inline-block"
    }
  })), " Plus"));
}
Object.assign(__ds_scope, { ActivityHeatmap });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/progress/ActivityHeatmap.jsx", error: String((e && e.message) || e) }); }

// components/progress/ComparisonPanel.jsx
try { (() => {
function ComparisonPanel({
  title = "Program vs performed",
  met = true,
  planned,
  performed,
  suggested,
  checks = [],
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: met ? "var(--gym-secondary-surface)" : "var(--gym-accent-surface)",
      borderRadius: "var(--radius-large)",
      padding: "16px",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-headline)"
    }
  }, title), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "6px",
      font: "var(--type-caption-bold)",
      color: met ? "var(--gym-secondary)" : "var(--gym-accent)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: "18px",
      height: "18px",
      borderRadius: "50%",
      background: met ? "var(--gym-secondary)" : "var(--gym-accent)",
      color: "#fff",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: "11px"
    }
  }, met ? "✓" : "!"), met ? "Met" : "Missed")), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: "10px",
      display: "flex",
      flexDirection: "column",
      gap: "4px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      font: "var(--type-body)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--gym-text-subdued)"
    }
  }, "Planned"), /*#__PURE__*/React.createElement("b", null, planned)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      font: "var(--type-body)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--gym-text-subdued)"
    }
  }, "Performed"), /*#__PURE__*/React.createElement("b", null, performed)), suggested && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      font: "var(--type-body)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--gym-text-subdued)"
    }
  }, "Suggested"), /*#__PURE__*/React.createElement("b", null, suggested))), checks.length > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "14px",
      marginTop: "12px",
      flexWrap: "wrap"
    }
  }, checks.map(c => /*#__PURE__*/React.createElement("span", {
    key: c,
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "5px",
      font: "var(--type-caption-bold)",
      color: "var(--gym-secondary)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: "14px",
      height: "14px",
      borderRadius: "50%",
      background: "var(--gym-secondary)",
      color: "#fff",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: "9px"
    }
  }, "\u2713"), c))));
}
Object.assign(__ds_scope, { ComparisonPanel });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/progress/ComparisonPanel.jsx", error: String((e && e.message) || e) }); }

// components/progress/RecommendationCard.jsx
try { (() => {
function RecommendationCard({
  exercise,
  rationale,
  acceptLabel,
  keepLabel,
  onAccept,
  onKeep,
  onEdit,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--gym-surface-card)",
      border: "1px solid var(--gym-primary-border,rgba(61,114,226,0.28))",
      borderRadius: "var(--radius-card)",
      padding: "18px 18px 14px",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      font: "var(--type-caption-bold)",
      letterSpacing: "var(--tracking-label)",
      color: "var(--gym-primary)"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "progression",
    size: 17,
    color: "var(--gym-primary)"
  }), "Progression recommendation"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-title-medium)",
      margin: "12px 0 8px"
    }
  }, exercise), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body)",
      color: "var(--gym-text)",
      marginBottom: "16px"
    }
  }, rationale), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "12px"
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    onClick: onAccept,
    style: {
      flex: 1,
      font: "var(--type-headline)",
      color: "#fff",
      background: "var(--gym-primary)",
      border: "none",
      borderRadius: "999px",
      padding: "14px",
      cursor: "pointer"
    }
  }, acceptLabel), /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    onClick: onKeep,
    style: {
      flex: 1,
      font: "var(--type-headline)",
      color: "var(--gym-text)",
      background: "var(--tint-current,#E7ECF8)",
      border: "none",
      borderRadius: "999px",
      padding: "14px",
      cursor: "pointer"
    }
  }, keepLabel)), /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    onClick: onEdit,
    style: {
      width: "100%",
      font: "var(--type-headline)",
      color: "var(--gym-text)",
      background: "none",
      border: "none",
      padding: "14px 0 4px",
      cursor: "pointer"
    }
  }, "Edit manually"));
}
Object.assign(__ds_scope, { RecommendationCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/progress/RecommendationCard.jsx", error: String((e && e.message) || e) }); }

// components/progress/StatusRow.jsx
try { (() => {
const STATUS = {
  completed: {
    label: "Completed",
    color: "var(--gym-secondary)",
    icon: "✓"
  },
  skipped: {
    label: "Skipped",
    color: "var(--gym-text-subdued)",
    icon: "○"
  },
  missed: {
    label: "Missed",
    color: "var(--gym-accent)",
    icon: "⚠"
  },
  "in-progress": {
    label: "In progress",
    color: "var(--gym-primary)",
    icon: "▸"
  },
  ready: {
    label: "Ready",
    color: "var(--gym-primary)",
    icon: "●"
  },
  scheduled: {
    label: "Scheduled",
    color: "var(--gym-text-subdued)",
    icon: "○"
  }
};
function StatusRow({
  title,
  detail,
  status,
  isToday,
  style
}) {
  const s = STATUS[status] || STATUS.scheduled;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "14px",
      padding: "12px 0",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-headline)",
      color: isToday ? "var(--gym-primary)" : "var(--gym-text)"
    }
  }, title), detail && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)",
      marginTop: "2px"
    }
  }, detail)), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "6px",
      font: "var(--type-caption-bold)",
      color: s.color
    }
  }, /*#__PURE__*/React.createElement("span", null, s.icon), s.label), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--gym-text-subdued)",
      fontSize: "15px"
    }
  }, "\u203A"));
}
Object.assign(__ds_scope, { StatusRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/progress/StatusRow.jsx", error: String((e && e.message) || e) }); }

// components/progress/UpcomingCalendar.jsx
try { (() => {
function UpcomingCalendar({
  days = [],
  onSelect,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--surface-card)",
      border: "var(--border-hairline)",
      borderRadius: "var(--radius-large)",
      boxShadow: "var(--shadow-row)",
      padding: "14px 12px",
      display: "flex",
      gap: "6px",
      ...style
    }
  }, days.map((d, i) => {
    const active = d.isToday;
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      className: onSelect ? "gym-press" : undefined,
      onClick: onSelect ? () => onSelect(i) : undefined,
      style: {
        flex: 1,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: "6px",
        padding: "8px 2px",
        borderRadius: "var(--radius-medium)",
        background: active ? "var(--gym-primary)" : d.workout ? "var(--gym-primary-tint)" : "transparent",
        cursor: onSelect ? "pointer" : undefined
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-caption)",
        color: active ? "rgba(255,255,255,0.8)" : "var(--gym-text-subtle)"
      }
    }, d.label), /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-subheadline-semibold)",
        fontVariantNumeric: "tabular-nums",
        color: active ? "#fff" : "var(--gym-text)"
      }
    }, d.date), d.workout ? /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-caption2,var(--type-caption))",
        fontWeight: 600,
        color: active ? "#fff" : "var(--gym-primary)",
        textAlign: "center",
        overflow: "hidden",
        textOverflow: "ellipsis",
        whiteSpace: "nowrap",
        maxWidth: "100%"
      }
    }, d.workout) : d.done ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "checkmark",
      size: 11,
      weight: 700,
      color: "var(--gym-secondary)"
    }) : /*#__PURE__*/React.createElement("span", {
      style: {
        width: "4px",
        height: "4px",
        borderRadius: "50%",
        background: "var(--gym-border)"
      }
    }));
  }));
}
Object.assign(__ds_scope, { UpcomingCalendar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/progress/UpcomingCalendar.jsx", error: String((e && e.message) || e) }); }

// components/workout/ExerciseCard.jsx
try { (() => {
function ExerciseCard({
  name,
  state = "collapsed",
  columns = ["Reps", "Weight (kg)"],
  prescription,
  lastTime,
  completedSets = 0,
  totalSets = 0,
  elapsed,
  children,
  onAddSet,
  onClick,
  style
}) {
  const current = state === "current";
  const done = state === "completed";
  return /*#__PURE__*/React.createElement("div", {
    className: onClick ? "gym-press" : undefined,
    onClick: onClick,
    style: {
      background: done ? "var(--gym-secondary-surface)" : current ? "var(--gym-current-set-surface)" : "var(--surface-card)",
      border: current ? "var(--border-focus)" : "var(--border-hairline)",
      borderRadius: "var(--radius-card)",
      padding: current ? "16px" : "12px",
      cursor: onClick ? "pointer" : undefined,
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-start",
      gap: "12px"
    }
  }, done && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "checkmarkCircle",
    size: 22,
    color: "var(--gym-secondary)",
    style: {
      marginTop: "2px"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      display: "flex",
      flexDirection: "column",
      gap: "4px"
    }
  }, current && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "6px",
      font: "var(--type-caption2-bold)",
      letterSpacing: "var(--tracking-label-tight)",
      color: "var(--gym-primary)",
      textTransform: "uppercase"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "circleFill",
    size: 9,
    color: "var(--gym-primary)"
  }), "Current exercise"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: current ? "var(--type-title-small)" : "var(--type-headline)"
    }
  }, name), prescription && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption-bold)",
      fontVariantNumeric: "tabular-nums",
      color: "var(--gym-primary)"
    }
  }, prescription), lastTime && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)"
    }
  }, lastTime), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-caption)",
      fontVariantNumeric: "tabular-nums",
      color: "var(--gym-text-subdued)"
    }
  }, completedSets, "/", totalSets, " sets", elapsed ? " \u2022 " + elapsed : "")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "8px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: "30px",
      height: "30px",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      borderRadius: "50%",
      background: "rgba(39,38,53,0.06)"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "ellipsis",
    size: 16,
    color: "var(--gym-text-subdued)"
  })), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevronDown",
    size: 18,
    weight: 600,
    color: "var(--gym-text-subdued)",
    style: {
      transform: current ? "none" : "rotate(-90deg)"
    }
  }))), current && children && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: "12px",
      display: "flex",
      flexDirection: "column",
      gap: "6px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "10px",
      padding: "0 12px",
      font: "var(--type-caption2-bold)",
      letterSpacing: "var(--tracking-label-tight)",
      color: "var(--gym-text-subdued)",
      textTransform: "uppercase"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: "32px"
    }
  }, "Set"), columns.map(c => /*#__PURE__*/React.createElement("span", {
    key: c,
    style: {
      flex: 1,
      textAlign: "center"
    }
  }, c)), /*#__PURE__*/React.createElement("span", {
    style: {
      width: "64px"
    }
  })), children, onAddSet && /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "text",
    icon: "plus",
    onClick: onAddSet,
    style: {
      alignSelf: "flex-start"
    }
  }, "Add set")));
}
Object.assign(__ds_scope, { ExerciseCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/workout/ExerciseCard.jsx", error: String((e && e.message) || e) }); }

// components/workout/RestTimer.jsx
try { (() => {
function RestTimer({
  state = "running",
  remaining,
  onAddTime,
  onPauseResume,
  onSkip,
  onContinue,
  style
}) {
  const msg = state === "ready" ? "Rest complete. Your next set is ready." : state === "paused" ? "Rest paused." : "Take a breath. Your next set is ready when you are.";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "16px 18px",
      background: "var(--tint-rest)",
      borderRadius: "var(--radius-section)",
      display: "flex",
      flexDirection: "column",
      gap: "12px",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "8px"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.IconChip, {
    icon: "timer",
    color: "accent",
    size: 42,
    surface: true,
    style: {
      background: "rgba(255,252,247,0.8)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-subheadline-semibold)"
    }
  }, "Rest between sets"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)"
    }
  }, msg)), state === "ready" ? /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-title-small-semibold)",
      color: "var(--gym-secondary)"
    }
  }, "Ready") : /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-title-small-semibold)",
      fontVariantNumeric: "tabular-nums",
      color: "var(--gym-accent)"
    }
  }, remaining)), state === "ready" ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "prominent",
    onClick: onContinue,
    style: {
      padding: "12px"
    }
  }, "Continue workout") : /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "8px",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    onClick: () => onAddTime && onAddTime(15),
    style: {
      font: "var(--type-subheadline-semibold)",
      color: "var(--gym-text)",
      background: "var(--tint-rest-chip)",
      border: "none",
      borderRadius: "999px",
      padding: "9px 18px",
      cursor: "pointer"
    }
  }, "+15s"), /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    onClick: () => onAddTime && onAddTime(30),
    style: {
      font: "var(--type-subheadline-semibold)",
      color: "var(--gym-text)",
      background: "var(--tint-rest-chip)",
      border: "none",
      borderRadius: "999px",
      padding: "9px 18px",
      cursor: "pointer"
    }
  }, "+30s"), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    onClick: onPauseResume,
    style: {
      width: "42px",
      height: "42px",
      borderRadius: "50%",
      background: "var(--tint-rest-chip)",
      border: "none",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: state === "paused" ? "play" : "pause",
    size: 15,
    color: "var(--gym-text)"
  })), /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    onClick: onSkip,
    style: {
      width: "42px",
      height: "42px",
      borderRadius: "50%",
      background: "var(--tint-rest-chip)",
      border: "none",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "skip",
    size: 15,
    color: "var(--gym-text)"
  }))));
}
Object.assign(__ds_scope, { RestTimer });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/workout/RestTimer.jsx", error: String((e && e.message) || e) }); }

// components/workout/SessionHeader.jsx
try { (() => {
function SessionHeader({
  title = "Today\u2019s workout",
  elapsed,
  completedSets = 0,
  totalSets = 0,
  exercises,
  style
}) {
  const pct = totalSets > 0 ? Math.min(100, completedSets / totalSets * 100) : 0;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "16px 18px",
      background: "var(--tint-rest)",
      borderRadius: "var(--radius-section)",
      display: "flex",
      flexDirection: "column",
      gap: "8px",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: "12px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-title-medium)",
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis",
      minWidth: 0
    }
  }, title), /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: "auto",
      font: "var(--type-title-small-semibold)",
      fontVariantNumeric: "tabular-nums"
    }
  }, elapsed)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      font: "var(--type-footnote-medium)",
      color: "var(--gym-text-subdued)",
      fontVariantNumeric: "tabular-nums"
    }
  }, /*#__PURE__*/React.createElement("span", null, totalSets === 0 ? "No exercises yet." : completedSets + " / " + totalSets + " sets"), exercises && /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: "auto"
    }
  }, exercises)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: "4px",
      borderRadius: "2px",
      background: "rgba(39,38,53,0.12)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      width: pct + "%",
      borderRadius: "2px",
      background: "var(--gym-secondary)",
      transition: "width var(--motion-layout)"
    }
  })));
}
Object.assign(__ds_scope, { SessionHeader });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/workout/SessionHeader.jsx", error: String((e && e.message) || e) }); }

// components/workout/SetRow.jsx
try { (() => {
function SetRow({
  index,
  values = [],
  state = "pending",
  note,
  locked,
  onToggle,
  onChange,
  style
}) {
  const bg = state === "completed" ? "var(--gym-secondary-surface)" : state === "current" ? "var(--gym-current-set-surface)" : "var(--gym-row-surface)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: bg,
      borderRadius: "var(--radius-large)",
      padding: "10px 12px",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "10px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: "32px",
      font: "var(--type-subheadline-semibold)",
      fontVariantNumeric: "tabular-nums",
      color: state === "completed" ? "var(--gym-secondary)" : "var(--gym-text)"
    }
  }, index), values.map((v, i) => /*#__PURE__*/React.createElement(__ds_scope.SetInput, {
    key: i,
    value: v,
    onChange: val => onChange && onChange(i, val),
    disabled: state === "completed",
    style: {
      flex: 1
    }
  })), /*#__PURE__*/React.createElement("button", {
    onClick: onToggle,
    className: "gym-press",
    style: {
      width: "36px",
      height: "36px",
      flex: "none",
      border: state === "completed" ? "none" : "2px solid var(--gym-primary)",
      borderRadius: "50%",
      cursor: "pointer",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      background: state === "completed" ? "var(--gym-secondary)" : "rgba(61,114,226,0.08)"
    }
  }, state === "completed" && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "checkmark",
    size: 18,
    weight: 700,
    color: "#fff"
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      width: "20px",
      display: "flex",
      justifyContent: "center"
    }
  }, state === "completed" ? locked && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "lock",
    size: 14,
    color: "var(--gym-text-subtle)"
  }) : /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "ellipsis",
    size: 16,
    color: "var(--gym-text-subtle)"
  }))), note && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)",
      padding: "8px 4px 0 42px"
    }
  }, note));
}
Object.assign(__ds_scope, { SetRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/workout/SetRow.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios-app/ActiveWorkoutScreen.jsx
try { (() => {
function ActiveWorkoutScreen({
  onClose,
  onFinish
}) {
  const {
    SessionHeader,
    SectionLabel,
    Button,
    ExerciseCard,
    SetRow,
    RestTimer
  } = window.GymTrackerDesignSystem_9b15a7;
  const [sets, setSets] = React.useState([{
    v: ["8", "50"],
    done: true
  }, {
    v: ["8", "50"],
    done: false
  }, {
    v: ["8", "50"],
    done: false
  }]);
  const [rest, setRest] = React.useState(null);
  const [elapsed, setElapsed] = React.useState(50);
  React.useEffect(() => {
    const t = setInterval(() => {
      setElapsed(e => e + 1);
      setRest(r => r === null ? null : r > 0 ? r - 1 : r);
    }, 1000);
    return () => clearInterval(t);
  }, []);
  const fmt = s => Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2);
  const doneCount = sets.filter(s => s.done).length;
  const toggle = i => setSets(p => {
    const n = p.map((x, j) => j === i ? {
      ...x,
      done: !x.done
    } : x);
    if (!p[i].done) setRest(90);
    return n;
  });
  const change = (i, col, val) => setSets(p => p.map((x, j) => j === i ? {
    ...x,
    v: x.v.map((v, k) => k === col ? val : v)
  } : x));
  const firstOpen = sets.findIndex(s => !s.done);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      height: "100%"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      padding: "12px 20px"
    }
  }, /*#__PURE__*/React.createElement(CircleButton, {
    icon: "minimize",
    onClick: onClose
  }), /*#__PURE__*/React.createElement(CircleButton, {
    icon: "trash",
    onClick: onClose
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      display: "flex",
      flexDirection: "column",
      gap: 16,
      padding: "8px 20px 20px"
    }
  }, /*#__PURE__*/React.createElement(SessionHeader, {
    elapsed: fmt(elapsed),
    completedSets: doneCount,
    totalSets: sets.length,
    exercises: "1 exercise"
  }), rest !== null && (rest > 0 ? /*#__PURE__*/React.createElement(RestTimer, {
    state: "running",
    remaining: fmt(rest),
    onAddTime: s => setRest(r => r + s),
    onSkip: () => setRest(null),
    onPauseResume: () => {}
  }) : /*#__PURE__*/React.createElement(RestTimer, {
    state: "ready",
    onContinue: () => setRest(null)
  })), /*#__PURE__*/React.createElement(SectionLabel, {
    trailing: /*#__PURE__*/React.createElement(Button, {
      variant: "text",
      icon: "plus",
      style: {
        padding: "0 4px",
        minHeight: "auto"
      }
    }, "Add")
  }, "Exercises"), /*#__PURE__*/React.createElement(ExerciseCard, {
    name: "Bench Press",
    state: "current",
    completedSets: doneCount,
    totalSets: sets.length,
    elapsed: "0:03",
    onAddSet: () => setSets(p => [...p, {
      v: ["8", "50"],
      done: false
    }])
  }, sets.map((s, i) => /*#__PURE__*/React.createElement(SetRow, {
    key: i,
    index: i + 1,
    values: s.v,
    locked: i === 0 && s.done,
    state: s.done ? "completed" : i === firstOpen ? "current" : "pending",
    note: i === 0 && s.done ? "RPE 8 \u00b7 Could do 2 more reps" : null,
    onToggle: () => toggle(i),
    onChange: (c, v) => change(i, c, v)
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 20px 24px",
      background: "var(--surface-page)",
      borderTop: "1px solid var(--gym-border)"
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "prominent",
    icon: "checkmark",
    disabled: doneCount === 0,
    onClick: onFinish
  }, "Review Workout")));
}
window.ActiveWorkoutScreen = ActiveWorkoutScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios-app/ActiveWorkoutScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios-app/HistoryScreen.jsx
try { (() => {
function HistoryScreen() {
  const {
    SegmentedControl,
    HistoryRow,
    IconChip
  } = window.GymTrackerDesignSystem_9b15a7;
  const [tab, setTab] = React.useState("Workouts");
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 16,
      padding: "40px 20px 120px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-display-medium)"
    }
  }, "History"), /*#__PURE__*/React.createElement(SegmentedControl, {
    options: ["Workouts", "Progress", "Records", "Balance"],
    value: tab,
    onChange: setTab
  }), tab === "Workouts" ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-title-small-semibold)",
      color: "var(--gym-text-subdued)"
    }
  }, "Today"), /*#__PURE__*/React.createElement(HistoryRow, {
    title: "Upper Body",
    date: "Today, 5:11 PM",
    duration: "59 min",
    exercises: "1 exercise",
    sets: "3 sets",
    onClick: () => {}
  })) : /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 10,
      padding: "64px 24px",
      textAlign: "center"
    }
  }, /*#__PURE__*/React.createElement(IconChip, {
    icon: tab === "Records" ? "trophy" : tab === "Balance" ? "chart" : "progression",
    color: "accent",
    size: 52
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-headline)"
    }
  }, tab, " needs more data"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-subheadline)",
      color: "var(--gym-text-subdued)"
    }
  }, "Complete more workouts to unlock ", tab.toLowerCase(), " insights.")));
}
window.HistoryScreen = HistoryScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios-app/HistoryScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios-app/HomeScreen.jsx
try { (() => {
function HomeScreen({
  onStartWorkout,
  hasHistory
}) {
  const {
    Button,
    Card,
    SectionLabel,
    ListRow,
    IconChip,
    HistoryRow
  } = window.GymTrackerDesignSystem_9b15a7;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 20,
      padding: "40px 20px 120px"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-subheadline)",
      fontWeight: 500,
      fontVariantNumeric: "tabular-nums",
      color: "var(--gym-accent)"
    }
  }, "Wednesday, Jul 15"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-display-medium)",
      margin: "6px 0 4px"
    }
  }, "Ready when you are."), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-subheadline)",
      color: "var(--gym-text-subdued)"
    }
  }, "Track your training today.")), /*#__PURE__*/React.createElement(Card, {
    variant: "outlined",
    onClick: onStartWorkout
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      font: "var(--type-caption-bold)",
      letterSpacing: "var(--tracking-label)",
      color: "var(--gym-primary)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 15,
      fontVariationSettings: "'FILL' 1"
    }
  }, "bolt"), "FREE WORKOUT"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-title-medium)",
      margin: "12px 0 10px"
    }
  }, "Free Workout"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-subheadline)",
      color: "var(--gym-text-subdued)",
      marginBottom: 16
    }
  }, "Jump in and add exercises as you go."), /*#__PURE__*/React.createElement(Button, {
    trailingIcon: "chevronRight",
    onClick: onStartWorkout,
    style: {
      pointerEvents: "none"
    }
  }, "Start workout")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, null, "Quick actions"), /*#__PURE__*/React.createElement(ListRow, {
    icon: "stack",
    color: "primary",
    surface: false,
    size: 38,
    title: /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-subheadline-semibold)"
      }
    }, "Use a Saved Workout"),
    subtitle: "Follow a reusable session",
    onClick: () => {}
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(SectionLabel, null, "History"), hasHistory ? /*#__PURE__*/React.createElement(HistoryRow, {
    title: "Upper Body",
    date: "Today, 5:11 PM",
    duration: "59 min",
    exercises: "1 exercise",
    sets: "3 sets",
    onClick: () => {}
  }) : /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 12,
      alignItems: "center",
      padding: 14,
      background: "var(--surface-card)",
      border: "var(--border-hairline)",
      borderRadius: "var(--radius-large)",
      boxShadow: "var(--shadow-row)"
    }
  }, /*#__PURE__*/React.createElement(IconChip, {
    icon: "history",
    color: "accent",
    size: 38
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-subheadline-semibold)"
    }
  }, "No workouts yet"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-caption)",
      color: "var(--gym-text-subdued)"
    }
  }, "Finish a workout to unlock performance and progression history.")))));
}
window.HomeScreen = HomeScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios-app/HomeScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios-app/LibraryScreen.jsx
try { (() => {
function LibraryScreen() {
  const {
    SearchField,
    SectionLabel,
    ListRow
  } = window.GymTrackerDesignSystem_9b15a7;
  const [q, setQ] = React.useState("");
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 16,
      padding: "12px 20px 120px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "flex-end"
    }
  }, /*#__PURE__*/React.createElement(CircleButton, {
    icon: "plus"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-display-medium)"
    }
  }, "Library"), /*#__PURE__*/React.createElement(SearchField, {
    value: q,
    onChange: setQ
  }), /*#__PURE__*/React.createElement(SectionLabel, null, "Browse"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(ListRow, {
    icon: "stack",
    color: "primary",
    title: /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-title-small)"
      }
    }, "Workouts"),
    subtitle: "Saved sessions and workout folders",
    count: 4,
    onClick: () => {}
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "plan",
    color: "accent",
    title: /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-title-small)"
      }
    }, "Programs"),
    subtitle: "Scheduled multi-week training",
    count: 0,
    onClick: () => {}
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "workout",
    color: "secondary",
    title: /*#__PURE__*/React.createElement("span", {
      style: {
        font: "var(--type-title-small)"
      }
    }, "Exercises"),
    subtitle: "Your complete exercise catalogue",
    count: 33,
    onClick: () => {}
  })));
}
window.LibraryScreen = LibraryScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios-app/LibraryScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios-app/chrome.jsx
try { (() => {
const StatusBar = ({
  dark
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "14px 24px 6px",
    font: "600 15px var(--font-body)",
    fontVariantNumeric: "tabular-nums",
    color: "var(--gym-text)"
  }
}, /*#__PURE__*/React.createElement("span", null, "7:34"), /*#__PURE__*/React.createElement("span", {
  style: {
    display: "flex",
    gap: 6,
    alignItems: "center"
  }
}, /*#__PURE__*/React.createElement("span", {
  className: "material-symbols-rounded",
  style: {
    fontSize: 16
  }
}, "signal_cellular_alt"), /*#__PURE__*/React.createElement("span", {
  className: "material-symbols-rounded",
  style: {
    fontSize: 16
  }
}, "wifi"), /*#__PURE__*/React.createElement("span", {
  className: "material-symbols-rounded",
  style: {
    fontSize: 18
  }
}, "battery_full_alt")));
const CircleButton = ({
  icon,
  color,
  onClick
}) => {
  const {
    Icon
  } = window.GymTrackerDesignSystem_9b15a7;
  return /*#__PURE__*/React.createElement("button", {
    className: "gym-press",
    onClick: onClick,
    style: {
      width: 52,
      height: 52,
      border: "none",
      borderRadius: "50%",
      background: "var(--surface-card)",
      boxShadow: "var(--shadow-card)",
      cursor: "pointer",
      display: "flex",
      alignItems: "center",
      justifyContent: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: icon,
    size: 22,
    weight: 600,
    color: color || "var(--gym-text)"
  }));
};
Object.assign(window, {
  StatusBar,
  CircleButton
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios-app/chrome.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconChip = __ds_scope.IconChip;

__ds_ns.SectionLabel = __ds_scope.SectionLabel;

__ds_ns.SearchField = __ds_scope.SearchField;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.SetInput = __ds_scope.SetInput;

__ds_ns.StepperRow = __ds_scope.StepperRow;

__ds_ns.HistoryRow = __ds_scope.HistoryRow;

__ds_ns.ListRow = __ds_scope.ListRow;

__ds_ns.TabBar = __ds_scope.TabBar;

__ds_ns.ActivityHeatmap = __ds_scope.ActivityHeatmap;

__ds_ns.ComparisonPanel = __ds_scope.ComparisonPanel;

__ds_ns.RecommendationCard = __ds_scope.RecommendationCard;

__ds_ns.StatusRow = __ds_scope.StatusRow;

__ds_ns.UpcomingCalendar = __ds_scope.UpcomingCalendar;

__ds_ns.ExerciseCard = __ds_scope.ExerciseCard;

__ds_ns.RestTimer = __ds_scope.RestTimer;

__ds_ns.SessionHeader = __ds_scope.SessionHeader;

__ds_ns.SetRow = __ds_scope.SetRow;

})();
