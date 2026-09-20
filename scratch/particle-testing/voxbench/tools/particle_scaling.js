// Simulation cost only, no rendering. Same structure as the demo.
const COLS=720, BANDS=96, R0=26, RMAX=250, DTH=Math.PI*2/COLS, CX=0, CY=0;
function bench(N, passes){
  const cap=N;
  const px=new Float32Array(cap),py=new Float32Array(cap),vx=new Float32Array(cap),vy=new Float32Array(cap),pm=new Uint8Array(cap);
  const height=new Float32Array(COLS).fill(R0+60), mat=new Uint8Array(COLS*BANDS);
  const BANDT=(RMAX-R0)/BANDS;
  let live=0;
  for(let i=0;i<cap;i++){ const a=Math.random()*Math.PI*2, r=R0+80+Math.random()*120, s=Math.random()*120;
    px[i]=Math.cos(a)*r; py[i]=Math.sin(a)*r; vx[i]=Math.cos(a+1.5)*s; vy[i]=Math.sin(a+1.5)*s; pm[i]=1+((Math.random()*5)|0); live++; }
  const REPOSE=[0,0.60,0.78,0.0,0.85,0.70,1.4], FLOW=[0,0.45,0.30,0.95,0.25,0.35,0.10];
  function step(dt){
    for(let i=0;i<live;i++){
      const dx=px[i],dy=py[i]; const r=Math.sqrt(dx*dx+dy*dy)||1e-4;
      const g=260/(0.35+r/RMAX);
      vx[i]-=dx/r*g*dt; vy[i]-=dy/r*g*dt; px[i]+=vx[i]*dt; py[i]+=vy[i]*dt;
      const nx=px[i],ny=py[i]; const nr=Math.sqrt(nx*nx+ny*ny);
      let a=Math.atan2(ny,nx); if(a<0)a+=Math.PI*2;
      const col=(a/DTH)|0;
      if(nr<=height[col]){ // land: deposit then respawn to hold N constant
        const b=Math.min(BANDS-1,Math.max(0,((height[col]-R0)/BANDT)|0)); mat[col*BANDS+b]=pm[i];
        height[col]=Math.min(RMAX-1,height[col]+0.02);
        const aa=Math.random()*Math.PI*2, rr=height[(aa/DTH)|0]+40;
        px[i]=Math.cos(aa)*rr; py[i]=Math.sin(aa)*rr; vx[i]=Math.cos(aa)*180; vy[i]=Math.sin(aa)*180;
      }
    }
  }
  function relax(){
    for(let p=0;p<passes;p++){ const off=p&1;
      for(let i=off;i<COLS;i+=2){ const j=(i+1)%COLS; const hi=height[i],hj=height[j]; const d=hi-hj; if(d===0)continue;
        const r=(hi+hj)*0.5; const bi=Math.min(BANDS-1,Math.max(0,((hi-R0)/BANDT)|0)); const m=mat[i*BANDS+bi]||1;
        const maxD=Math.tan(REPOSE[m])*r*DTH; const ad=d<0?-d:d;
        if(ad>maxD){ const mv=(ad-maxD)*0.5*FLOW[m]; if(d>0){height[i]-=mv;height[j]+=mv;}else{height[i]+=mv;height[j]-=mv;} } } }
  }
  for(let w=0;w<20;w++){step(1/60);relax();}           // warm up
  const t0=process.hrtime.bigint();
  const F=120; for(let f=0;f<F;f++){ step(1/60); relax(); }
  const t1=process.hrtime.bigint();
  return Number(t1-t0)/1e6/F;
}
console.log(' particles      sim ms/frame     ns per particle    would-be pairwise tests');
for(const N of [10000,50000,100000,250000,500000,1000000]){
  const ms=bench(N,10);
  console.log(String(N).padStart(10)+'   '+ms.toFixed(3).padStart(10)+'    '+((ms*1e6/N).toFixed(1)).padStart(10)+'    '+(N*(N-1)/2).toExponential(2).padStart(12));
}
console.log('\nrelaxation pass cost alone (720 columns), by pass count:');
for(const p of [2,10,40]){ const a=bench(1000,p); console.log('  '+String(p).padStart(3)+' passes: '+a.toFixed(3)+' ms/frame total with only 1k particles'); }
