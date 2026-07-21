
function LibraryScreen(){
  const {SearchField,SectionLabel,ListRow}=window.GymTrackerDesignSystem_9b15a7;
  const [q,setQ]=React.useState("");
  return <div style={{display:"flex",flexDirection:"column",gap:16,padding:"12px 20px 120px"}}>
    <div style={{display:"flex",justifyContent:"flex-end"}}><CircleButton icon="plus"/></div>
    <div style={{font:"var(--type-display-medium)"}}>Train</div>
    <SearchField value={q} onChange={setQ}/>
    <SectionLabel>Browse</SectionLabel>
    <div style={{display:"flex",flexDirection:"column",gap:10}}>
      <ListRow icon="stack" color="primary" title={<span style={{font:"var(--type-title-small)"}}>Workouts</span>} subtitle="Saved sessions and workout folders" count={4} onClick={()=>{}}/>
      <ListRow icon="plan" color="accent" title={<span style={{font:"var(--type-title-small)"}}>Programs</span>} subtitle="Scheduled multi-week training" count={0} onClick={()=>{}}/>
      <ListRow icon="workout" color="secondary" title={<span style={{font:"var(--type-title-small)"}}>Exercises</span>} subtitle="Your complete exercise catalogue" count={33} onClick={()=>{}}/>
    </div>
  </div>;
}
window.LibraryScreen=LibraryScreen;
