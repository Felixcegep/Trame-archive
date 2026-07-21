
function ActiveWorkoutScreen({onClose,onFinish}){
  const {SessionHeader,SectionLabel,Button,ExerciseCard,SetRow,RestTimer}=window.GymTrackerDesignSystem_9b15a7;
  const [sets,setSets]=React.useState([{v:["8","50"],done:true},{v:["8","50"],done:false},{v:["8","50"],done:false}]);
  const [rest,setRest]=React.useState(null);
  const [elapsed,setElapsed]=React.useState(50);
  React.useEffect(()=>{const t=setInterval(()=>{setElapsed(e=>e+1);setRest(r=>r===null?null:(r>0?r-1:r));},1000);return ()=>clearInterval(t);},[]);
  const fmt=s=>Math.floor(s/60)+":"+("0"+s%60).slice(-2);
  const doneCount=sets.filter(s=>s.done).length;
  const toggle=i=>setSets(p=>{const n=p.map((x,j)=>j===i?{...x,done:!x.done}:x);if(!p[i].done)setRest(90);return n;});
  const change=(i,col,val)=>setSets(p=>p.map((x,j)=>j===i?{...x,v:x.v.map((v,k)=>k===col?val:v)}:x));
  const firstOpen=sets.findIndex(s=>!s.done);
  return <div style={{display:"flex",flexDirection:"column",height:"100%"}}>
    <div style={{display:"flex",justifyContent:"space-between",padding:"12px 20px"}}>
      <CircleButton icon="minimize" onClick={onClose}/>
      <CircleButton icon="trash" onClick={onClose}/>
    </div>
    <div style={{flex:1,overflowY:"auto",display:"flex",flexDirection:"column",gap:16,padding:"8px 20px 20px"}}>
      <SessionHeader elapsed={fmt(elapsed)} completedSets={doneCount} totalSets={sets.length} exercises="1 exercise"/>
      {rest!==null&&(rest>0
        ?<RestTimer state="running" remaining={fmt(rest)} onAddTime={s=>setRest(r=>r+s)} onSkip={()=>setRest(null)} onPauseResume={()=>{}}/>
        :<RestTimer state="ready" onContinue={()=>setRest(null)}/>)}
      <SectionLabel trailing={<Button variant="text" icon="plus" style={{padding:"0 4px",minHeight:"auto"}}>Add</Button>}>Exercises</SectionLabel>
      <ExerciseCard name="Bench Press" state="current" completedSets={doneCount} totalSets={sets.length} elapsed="0:03" onAddSet={()=>setSets(p=>[...p,{v:["8","50"],done:false}])}>
        {sets.map((s,i)=><SetRow key={i} index={i+1} values={s.v} locked={i===0&&s.done}
          state={s.done?"completed":(i===firstOpen?"current":"pending")}
          note={i===0&&s.done?"RPE 8 \u00b7 Could do 2 more reps":null}
          onToggle={()=>toggle(i)} onChange={(c,v)=>change(i,c,v)}/>)}
      </ExerciseCard>
    </div>
    <div style={{padding:"12px 20px 24px",background:"var(--surface-page)",borderTop:"1px solid var(--gym-border)"}}>
      <Button variant="prominent" icon="checkmark" disabled={doneCount===0} onClick={onFinish}>Review Workout</Button>
    </div>
  </div>;
}
window.ActiveWorkoutScreen=ActiveWorkoutScreen;
