import React from "react";
const COLORS={primary:"var(--gym-primary)",secondary:"var(--gym-secondary)",accent:"var(--gym-accent)",neutral:"var(--gym-text-subdued)"};
const TINTS={primary:"var(--gym-primary-surface)",secondary:"var(--gym-secondary-surface)",accent:"var(--gym-accent-surface)",neutral:"var(--gym-row-surface)"};
export function Badge({color="accent",variant="tint",children,style}){
  return <span style={{display:"inline-flex",alignItems:"center",font:"var(--type-caption2-bold)",color:COLORS[color],background:variant==="card"?"rgba(255,252,247,0.72)":TINTS[color],borderRadius:"var(--radius-pill)",padding:"3px 8px",whiteSpace:"nowrap",...style}}>{children}</span>;
}