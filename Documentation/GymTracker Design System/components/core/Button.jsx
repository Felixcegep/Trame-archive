import React from "react";
import { Icon } from "./Icon.jsx";
const COLORS={primary:"var(--gym-primary)",secondary:"var(--gym-secondary)",accent:"var(--gym-accent)",destructive:"var(--gym-destructive)"};
const TINTS={primary:"var(--gym-primary-tint)",secondary:"var(--gym-secondary-tint)",accent:"var(--gym-accent-tint)",destructive:"rgba(255,59,48,0.12)"};
export function Button({variant="primary",color="primary",icon,trailingIcon,children,fullWidth,disabled,onClick,style}){
  const c=COLORS[color]||color;
  const base={display:"inline-flex",alignItems:"center",justifyContent:"center",gap:"8px",border:"none",cursor:disabled?"default":"pointer",fontFamily:"var(--font-body)",opacity:disabled?0.45:1,whiteSpace:"nowrap"};
  const variants={
    primary:{font:"var(--type-subheadline-bold)",color:"#fff",background:c,borderRadius:"var(--radius-pill)",padding:"12px 20px"},
    prominent:{font:"var(--type-headline)",color:"#fff",background:c,borderRadius:"var(--radius-button)",padding:"17px 20px",width:"100%"},
    bordered:{font:"var(--type-subheadline-semibold)",color:c,background:TINTS[color]||"var(--gym-row-surface)",borderRadius:"var(--radius-medium)",padding:"8px 14px",minHeight:"36px"},
    text:{font:"var(--type-subheadline-semibold)",color:c,background:"none",padding:"6px 4px",minHeight:"32px"}
  };
  return <button className="gym-press" disabled={disabled} onClick={onClick} style={{...base,...variants[variant],...(fullWidth?{width:"100%"}:{}),...style}}>
    {icon&&<Icon name={icon} size={variant==="prominent"?18:16}/>}{children}{trailingIcon&&<Icon name={trailingIcon} size={14} weight={700}/>}
  </button>;
}