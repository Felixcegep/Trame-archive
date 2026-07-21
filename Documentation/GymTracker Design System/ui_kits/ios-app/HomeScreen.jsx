
function HomeScreen({onStartWorkout,hasHistory}){
  const {Button,Card,SectionLabel,ListRow,IconChip,HistoryRow}=window.GymTrackerDesignSystem_9b15a7;
  return <div style={{display:"flex",flexDirection:"column",gap:20,padding:"40px 20px 120px"}}>
    <div>
      <div style={{font:"var(--type-subheadline)",fontWeight:500,fontVariantNumeric:"tabular-nums",color:"var(--gym-accent)"}}>Wednesday, Jul 15</div>
      <div style={{font:"var(--type-display-medium)",margin:"6px 0 4px"}}>Ready when you are.</div>
      <div style={{font:"var(--type-subheadline)",color:"var(--gym-text-subdued)"}}>Track your training today.</div>
    </div>
    <Card variant="outlined" onClick={onStartWorkout}>
      <div style={{display:"flex",alignItems:"center",gap:8,font:"var(--type-caption-bold)",letterSpacing:"var(--tracking-label)",color:"var(--gym-primary)"}}>
        <span className="material-symbols-rounded" style={{fontSize:15,fontVariationSettings:"'FILL' 1"}}>bolt</span>FREE WORKOUT
      </div>
      <div style={{font:"var(--type-title-medium)",margin:"12px 0 10px"}}>Free Workout</div>
      <div style={{font:"var(--type-subheadline)",color:"var(--gym-text-subdued)",marginBottom:16}}>Jump in and add exercises as you go.</div>
      <Button trailingIcon="chevronRight" onClick={onStartWorkout} style={{pointerEvents:"none"}}>Start workout</Button>
    </Card>
    <div style={{display:"flex",flexDirection:"column",gap:8}}>
      <SectionLabel>Quick actions</SectionLabel>
      <ListRow icon="stack" color="primary" surface={false} size={38} title={<span style={{font:"var(--type-subheadline-semibold)"}}>Use a Saved Workout</span>} subtitle="Follow a reusable session" onClick={()=>{}}/>
    </div>
    <div style={{display:"flex",flexDirection:"column",gap:8}}>
      <SectionLabel>History</SectionLabel>
      {hasHistory
        ?<HistoryRow title="Upper Body" date="Today, 5:11 PM" duration="59 min" exercises="1 exercise" sets="3 sets" onClick={()=>{}}/>
        :<div style={{display:"flex",gap:12,alignItems:"center",padding:14,background:"var(--surface-card)",border:"var(--border-hairline)",borderRadius:"var(--radius-large)",boxShadow:"var(--shadow-row)"}}>
          <IconChip icon="history" color="accent" size={38}/>
          <div>
            <div style={{font:"var(--type-subheadline-semibold)"}}>No workouts yet</div>
            <div style={{font:"var(--type-caption)",color:"var(--gym-text-subdued)"}}>Finish a workout to unlock performance and progression history.</div>
          </div>
        </div>}
    </div>
  </div>;
}
window.HomeScreen=HomeScreen;
