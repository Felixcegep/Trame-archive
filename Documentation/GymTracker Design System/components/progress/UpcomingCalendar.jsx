import React from "react";
import { Icon } from "../core/Icon.jsx";
export function UpcomingCalendar({days=[],onSelect,style}){
  return <div style={{background:"var(--surface-card)",border:"var(--border-hairline)",borderRadius:"var(--radius-large)",boxShadow:"var(--shadow-row)",padding:"14px 12px",display:"flex",gap:"6px",...style}}>
    {days.map((d,i)=>{
      const active=d.isToday;
      return <div key={i} className={onSelect?"gym-press":undefined} onClick={onSelect?()=>onSelect(i):undefined} style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",gap:"6px",padding:"8px 2px",borderRadius:"var(--radius-medium)",background:active?"var(--gym-primary)":d.workout?"var(--gym-primary-tint)":"transparent",cursor:onSelect?"pointer":undefined}}>
        <span style={{font:"var(--type-caption)",color:active?"rgba(255,255,255,0.8)":"var(--gym-text-subtle)"}}>{d.label}</span>
        <span style={{font:"var(--type-subheadline-semibold)",fontVariantNumeric:"tabular-nums",color:active?"#fff":"var(--gym-text)"}}>{d.date}</span>
        {d.workout
          ?<span style={{font:"var(--type-caption2,var(--type-caption))",fontWeight:600,color:active?"#fff":"var(--gym-primary)",textAlign:"center",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",maxWidth:"100%"}}>{d.workout}</span>
          :d.done
            ?<Icon name="checkmark" size={11} weight={700} color="var(--gym-secondary)"/>
            :<span style={{width:"4px",height:"4px",borderRadius:"50%",background:"var(--gym-border)"}}></span>}
      </div>;
    })}
  </div>;
}
