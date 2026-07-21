import React from "react";
const VARIANTS={
  standard:{background:"var(--surface-card)",border:"var(--border-hairline)",boxShadow:"var(--shadow-card)"},
  elevated:{background:"var(--gym-card-elevated)",border:"var(--border-hairline)",boxShadow:"var(--shadow-card)"},
  outlined:{background:"var(--surface-card)",border:"var(--border-outline)",boxShadow:"var(--shadow-card)"},
  current:{background:"var(--gym-current-set-surface)",border:"var(--border-focus)"},
  completed:{background:"var(--gym-secondary-surface)",border:"var(--border-hairline)"},
  accent:{background:"var(--gym-accent-surface)",border:"var(--border-hairline)"},
  muted:{background:"var(--gym-muted-surface)",border:"none"}
};
const RADII={card:"var(--radius-card)",section:"var(--radius-section)",large:"var(--radius-large)"};
export function Card({variant="standard",radius="card",padding="16px",onClick,children,style}){
  const Tag=onClick?"button":"div";
  return <Tag className={onClick?"gym-press":undefined} onClick={onClick} style={{display:"block",width:"100%",textAlign:"left",font:"inherit",color:"var(--gym-text)",cursor:onClick?"pointer":undefined,borderRadius:RADII[radius]||radius,padding,boxSizing:"border-box",...VARIANTS[variant],...style}}>{children}</Tag>;
}