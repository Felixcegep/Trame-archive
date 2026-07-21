import React from "react";
import { Icon } from "./Icon.jsx";
const COLORS={primary:"var(--gym-primary)",secondary:"var(--gym-secondary)",accent:"var(--gym-accent)",neutral:"var(--gym-text)"};
const TINTS={primary:"var(--gym-primary-tint)",secondary:"var(--gym-secondary-tint)",accent:"var(--gym-accent-tint)",neutral:"rgba(39,38,53,0.06)"};
const SURFACES={primary:"var(--gym-primary-surface)",secondary:"var(--gym-secondary-surface)",accent:"var(--gym-accent-surface)",neutral:"var(--gym-row-surface)"};
export function IconChip({icon,color="primary",shape="circle",size=38,surface=false,iconSize,filled=true,style}){
  return <div style={{width:size,height:size,flex:"none",display:"flex",alignItems:"center",justifyContent:"center",borderRadius:shape==="circle"?"50%":"var(--radius-medium)",background:surface?SURFACES[color]:TINTS[color],color:COLORS[color],...style}}>
    <Icon name={icon} size={iconSize||Math.round(size*0.47)} filled={filled}/>
  </div>;
}