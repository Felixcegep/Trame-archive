import React from "react";
import { Icon } from "../core/Icon.jsx";
function Meta({icon,children}){return <span style={{display:"inline-flex",alignItems:"center",gap:"5px",font:"var(--type-caption)",color:"var(--gym-text-subdued)"}}><Icon name={icon} size={14} filled={false} color="var(--gym-text-subdued)"/>{children}</span>;}
export function HistoryRow({title,date,duration,exercises,sets,source,onClick,style}){
  return <div className={onClick?"gym-press":undefined} onClick={onClick} style={{display:"flex",alignItems:"center",gap:"12px",padding:"14px 16px",background:"var(--surface-card)",borderRadius:"var(--radius-large)",border:"var(--border-hairline)",boxShadow:"var(--shadow-row)",cursor:onClick?"pointer":undefined,...style}}>
    <div style={{flex:1,minWidth:0,display:"flex",flexDirection:"column",gap:"8px"}}>
      <div style={{display:"flex",alignItems:"baseline",gap:"12px"}}>
        <span style={{font:"var(--type-headline)",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{title}</span>
        <span style={{marginLeft:"auto",font:"var(--type-caption)",color:"var(--gym-text-subdued)",whiteSpace:"nowrap"}}>{date}</span>
      </div>
      <div style={{display:"flex",gap:"12px",flexWrap:"wrap"}}>
        {duration&&<Meta icon="timer">{duration}</Meta>}
        {exercises&&<Meta icon="workout">{exercises}</Meta>}
        {sets&&<Meta icon="checkmarkCircle">{sets}</Meta>}
      </div>
      {source&&<span style={{display:"inline-flex",alignItems:"center",gap:"5px",font:"var(--type-caption)",color:"var(--gym-accent)"}}><Icon name="folders" size={13} color="var(--gym-accent)"/>From {source}</span>}
    </div>
    {onClick&&<Icon name="chevronRight" size={14} weight={700} color="var(--gym-text-subtle)"/>}
  </div>;
}