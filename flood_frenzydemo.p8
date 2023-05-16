pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- flood frenzy
-- by froggo

mapx,mapy=128,128
usemouse=false
mainmenu=true
tutomenu=false
difficulty=2
diffname={"routine","normal","severe","hopeless","massacre","american"}
--massacre?
function setmusicpattern(index,channel,on)
    local base=0x3100+index*4+channel
    local val=peek(base)
    if on then
        val=val&~0b01000000
    else
        val=val|0b01000000
    end
    poke(base,val)
end

function setmusic(channel,on)
    for i=0,7 do
        setmusicpattern(i,channel,on)
    end
end

curmusic=0
musicon=true
function playmusic(index,trans)
    curmusic=index
    if musicon then
        music(curmusic,trans)
    end
end

function musictoggle()
    local on = not musicon
    if on then
        if not musicon then
            music(curmusic,500)
            musicon=true
        end
    else
        if musicon then
            music(-1,500)
            musicon=false
        end
    end
end

setmusic(0,true)
setmusic(1,false)
setmusic(2,false)
playmusic(0,1000)

cheat=false

function fixrnd(x,y)
    return (sin(x*824.515+y*342.723)*271.415)%1
end

function lerp(a,b,v)
    return a*(1-v)+b*v
end

function smoothrnd(x,y)
    local i=flr(x)
    local j=flr(y)
    local a=lerp(fixrnd(i,j),fixrnd(i+1,j),x%1)
    local b=lerp(fixrnd(i,j+1),fixrnd(i+1,j+1),x%1)
    return lerp(a,b,y%1)
end

function noise(x,y)
    local val = smoothrnd(x/8,y/8)
    val += (smoothrnd(x/4,y/4)-.5)*1
    --val += smoothrnd(x/2,y/2)
    return val
end

function startgame()
    frame=0

    water={}
    sources={}
    sensors={}
    saveanim={}
    particles={}
    restcompute=-1
    finish=false
    finishtimer=100
   
    savereserve=0
    savedelay=({1000,850,730,660,590,590})[difficulty]
    savenext=savedelay
    sourcetime=({2000,4000,4500,5000,5500,5500})[difficulty]
   
    powerstart=({300,300,200,100,090,090})[difficulty]
    power=powerstart
    powergain=({0.8,.45,.4,.35,0.3,20.3})[difficulty]
    maxpower=500
    totalpeople=({6,10,14,18,24,200})[difficulty]
   
    cls()
   
        -- write to spritesheet
    poke(0x5f55,0x00)
   
    cls()
    local offx,offy=rnd(9000),rnd(9000)
    for i=0,mapx do
        for j=0,mapy do
            local v=noise(i+offx,j+offy)
            local isground=v<.7
            local groundtype=v<.5 and 0 or 1
            pset(i,j,isground and groundtype or 13)
        end  
    end
   
    begin = {x=flr(mapx/2),y=0}
    add(sources, begin)
    circfill(begin.x,begin.y+12,7,13)
    circfill(begin.x+rnd(10)-5,begin.y+25,7,13)
    rectfill(0,0,128,10,13)

    --[[
    for i=1,3 do
        local p=i*10
        rectfill(p,0,p,128,13)
        rectfill(p+90,0,p+90,128,13)
    end
    ]]
   
    --[[
    for p=0,10 do
        local px,py=rnd(100)+10,rnd(80)+30
        rectfill(px-5,py-5,px+5,py+5,13)
        rect(px-5,py-5,px+5,py+5,0)
        add(sources,{x=px,y=py})
    end
    ]]--
   
    local leftcount=1+rnd(totalpeople-1)
    for p=1,totalpeople do
        --local left=rnd()>.5 and 1 or 0
        local left=p>leftcount and 1 or 0
        local px,py=flr(rnd(25)+5+left*94),flr(rnd(80)+30)
        --if px%10==0 then px+=1 end
        add(sensors,{x=px,y=py,water=0,dead=false})
    end
    local verif=false
    while not verif do
        verif=true
        for a=1,#sensors do
                for b=a+1,#sensors do
                    if sensors[a].x==sensors[b].x then
                        sensors[b].x+=1
                        verif=false
                    end
                end      
        end
    end
    for p=1,#sensors do
        local cur=sensors[p]
        circfill(cur.x,cur.y,4,13)
        circfill(cur.x,cur.y+4,3,0)  
    end
    for p=1,#sensors do
        local cur=sensors[p]
        rectfill(cur.x,cur.y,cur.x,cur.y-4,13)
    end
    for p=1,#sensors do
        local cur=sensors[p]
        local tx=cur.x+rnd(8)-4
        cur.history={}
        cur.hisanim=1
        --rectfill(tx,cur.y,tx,0,13)
        for j=cur.y,0,-1 do
            tx=max(1,min(127,tx))
            pset(tx,j,13)
            pset(tx,j-1,13)
            add(cur.history,{x=tx,y=j})
            tx+=rnd(2)-1
        end
    end
       
        -- write to screen again
    poke(0x5f55,0x60)
   
end

function propagate(part,offx,offy)
    local nx,ny=part.x+offx,part.y+offy
    local new=pget(nx,ny)
    if new==13 then
        pset(part.x,part.y,13)
        part.x,part.y=nx,ny
        pset(part.x,part.y,7)
        --add(nextlimit,part)
        motioncount+=1
        return true
    else
        return false
    end
end

function uppart(index)
    local cur=water[index]
    if not propagate(cur,0,1) then
        if cur.pref==0 then
            if not propagate(cur,1,0) then
                cur.pref=1-cur.pref
                pset(cur.x,cur.y,12)
            end
        else
            if not propagate(cur,-1,0) then
                cur.pref=1-cur.pref
                pset(cur.x,cur.y,12)
            end
        end          
    end
end

wstep=0
function waterstep()

    if power<maxpower then
        power+=powergain
    end
    if cheat then
        power=maxpower
    end
   
    local watercount=#water
    local sourcecount=#sources
    if sourcecount==1 and watercount>sourcetime then
        add(sources,{x=begin.x-1,y=0})  
    end
    if sourcecount==2 and watercount>sourcetime*2 then
        add(sources,{x=begin.x+1,y=0})
    end
   
    motioncount=0
    for i=1,#sources do
        local cur=sources[i]
        local prev = pget(cur.x,cur.y)
        if prev !=12 and prev != 7 then
            pset(cur.x,cur.y,7)
            local npref=rnd()>.5 and 1 or 0
            --local npref=wstep%2
            add(water,{x=cur.x,y=cur.y,pref=npref})
            motioncount+=1
        end
    end

    local done=true  
    if restcompute>0 then

        for i=restcompute,#water do
            uppart(i)
            if stat(1)>0.95 then
                restcompute=i+1
                done=false
                break
            end
        end
        if done then
            restcompute=-1
        end      
    end
   
    if done then
        for i=1,#water do
            uppart(i)
            if stat(1)>0.95 then
                restcompute=i+1
                break
            end
        end
    end
    wstep+=1
end

startedgame=false
function _init()
    poke(0x5f2d, 1)
    menuitem(2, "toggle music", musictoggle)
end

function upwater()
    waterstep()
    --[[if btn(5) then
        for i=1,10 do
            waterstep()
            if stat(1)>=.8 then
                break
            end
        end
    end
    ]]
end

function dig(x,y,size)
    local num=0
    local miss=0
    for j=-size,size do
        for i=-size,size do
            if i*i+j*j<size*size+4 then
                if x+i>=0 and x+i<128 and y+j>=0 and y+j<128 then
                    local ground=pget(x+i,y+j)
                    if ground!=12 and ground !=7  and ground !=13 then
                        if power>=1 then
                            power-=1
                            pset(x+i,y+j,13)
                            add(particles,{x=x+i,y=y+j,vx=rnd(2)-1,vy=rnd(2)-1,dur=20,c=1})
                            num+=1
                        else
                            miss+=1
                        end
                    end
                end
            end
        end
    end
    if lastdigsfx<1 then
        if num>miss then
            sfx(5)
            lastdigsfx=5
        end
        if miss>0 then
            sfx(6)
            lastdigsfx=5
        end
    end
end

function gauge(x,y,sx,val,maxval,col)
    rectfill(x-1,y-1,x+sx+1,y+1,1)
    rectfill(x,y,x+sx,y,13)
    local factor=val/maxval
    rect(x,y,x+sx*factor,y,col)
end

pmpx,pmpy=64,64
mpx,mpy=64,64
tmpx,tmpy=64,64
pmb1=false
spx,spy=1,1
waitclic=true
starteddrag=false
frame=0
lastdigsfx=0
lastdrownsfx=0

function _update()
    if mainmenu then
        if btnp(2) then
            difficulty-=1
            usemouse=false
        end
        if btnp(3) then
            difficulty+=1
            usemouse=false          
        end
        difficulty=(difficulty-1)%6+1
        local mb1 = stat(34)%2==1
        if btnp(4) or btnp(5) or (mb1 and not pmb1) then
            tutomenu=true
            frame=0
            mainmenu=false
        end
        pmb1=mb1
        return
    end
    if tutomenu then
        local mb1 = stat(34)%2==1
        if btnp(4) or btnp(5) or (mb1 and not pmb1) then
            tutomenu=false
            startedgame=false
        end
        pmb1=mb1
        return
    end
    if not startedgame then
        startgame()
        startedgame=true
    end
    if btn(0) then
        spx+=0.3
        mpx-=spx
        usemouse=false
    end
    if btn(1) then
        spx+=0.3
        mpx+=spx
        usemouse=false
    end  
    if btn(2) then
        spy+=0.3  
        mpy-=spy
        usemouse=false
    end
    if btn(3) then
        spy+=0.3
        mpy+=spy
        usemouse=false
    end  
    spx=lerp(spx,.5,0.3)
    spy=lerp(spy,.5,0.3)
end

function printc(t,x,y,c)
    x-=#t*2
    print(t,x-1,y,1)  
    print(t,x+1,y,1)  
    print(t,x,y-1,1)  
    print(t,x,y+1,1)          
    print(t,x,y,c)
end

function drawmouse(x,y)
    line(x,y,x+4,y+4,7)
    line(x,y,x+2,y,7)
    line(x,y,x,y+2,7)
end

function printt(tab,x,y,w,mchar,c)
    local prevlines=0
    for i=1,#tab do
        local par=tab[i]
        if type(par) != "string" then
            if mchar>=prevlines then
                if par.gauge then
                    gauge(x,y+4,45,frame%100,100,par.gauge)
                end
            end
            prevlines+=5
            y+=8
        else
            local cw=0
            local word=""
            for j=1,#par do
                local cur=sub(par,j,j)
                word=word..cur
                if cur==" " or j==#par then
                    local si=#word*4
                    if cw+si>w then
                        y+=6
                        cw=0
                    end
                    print(sub(word,1,max(0,mchar-prevlines)),x+cw,y,c)
                    prevlines+=#word
                    cw+=si
                    word=""
                end
            end
            prevlines+=10
            y+=8
        end
    end

end

function printmusic(index)
    local base=0x3100+index*4
    local t=""
    for i=0,3 do
        local val=peek(base+i)
        val=val&0b01000000
        t=t..val.." "
    end
    print(t,1,1,7)
end

function _draw()

    local nmpx,nmpy=stat(32),stat(33)
    if nmpx!=tmpx or nmpy!=tmpy then
        if frame>1 then
            usemouse=true
        end
    end
    tmpx,tmpy=nmpx,nmpy
   
    if usemouse and frame>1 then
        mpx,mpy=nmpx,nmpy
    end
   
    if mainmenu then
        cls()
        for i=0,11 do
            pal(i,i==(frame%11) and (rnd()>.1 and 12 or 7) or 0)
        end
        spr(1,30,20,8,4)
        pal()
       
        for i=0,50 do
            local x,y=36+rnd(60),20+rnd(17)
            if pget(x-1,y+1)>0 or pget(x+1,y+1)>0 or pget(x-1,y-1)>0 or pget(x+1,y-1)>0 then
                pset(x,y,rnd()>.1 and 12 or 7)
            end
        end
               
        --printmusic(0)
        printc("by froggo",64,1,6)
        printc("select difficulty",64,64,7)
        for i=1,#diffname do
            local c=6
            local height=68+i*6
            if usemouse then
                if abs(mpy-height-3)<3 then
                    difficulty=i
                end
            end
            if i==difficulty then
                print("->",41,height,7)
                c=7
            end
         
            if (i==5 and i==difficulty) then
           		print(diffname[i],50,height,8)

            elseif (i==6 and i==diffuculty) then
  
             print(diffname[i],50,height,5)
          
            else 
            
             print(diffname[i],50,height,c)
             
            end
           
        end
   
        print("   press c or click to start",2,115,7)
       -- print("to start",2,116,7)
        if usemouse then
            drawmouse(mpx,mpy)
        end
        frame+=1
        return
    end
    if tutomenu then
        cls(0)
    printt({"it's flood season"
        ,"you must delay the rising water until you manage to save everyone"
        ,"dig the rock to direct water to the empty caverns while avoiding drowning people stuck in caves"
        ,{gauge=11}
        ,"your digging power is limited, it recharges over time"
        ,{gauge=7}
        ,"at regular intervals, you can save someone by sending your rescue team"
        ,"   press c or click to start"
        },4,4,120,flr(frame*.7)-5,7)
        if usemouse then
            drawmouse(mpx,mpy)
        end
        frame+=1
        return
    end

    if not startedgame then
        cls(0)
        printc("loading",64,64,7)
        return
    end
   
    -- write to spritesheet
    poke(0x5f55,0x00)
       
    upwater()
   
    for i=1,#sensors do
        local s=sensors[i]
        if pget(s.x,s.y,8) == 12 then
            s.water+=1
        else
            s.water=0
        end
        if s.water>200 then
            if not s.dead then
                s.dead=true
                sfx(8)
            end
        end
        local ground=pget(s.x,s.y+1)
        if ground == 13 or ground == 12 or ground == 7 or ground == 12 then
            s.y+=1
        end
    end
   
   
    local nearest=nil
    local neardist=40
    for i=1,#sensors do
        local s=sensors[i]
        if not s.dead then
            if savereserve>0 then
                local dx,dy=s.x-mpx,s.y-mpy
                local dist=dx*dx+dy*dy
                if dist<neardist then
                    nearest=s
                    neardist=dist
                end
            end
        end
    end
   
    local mb1 = stat(34)%2==1
    if mb1 or btn(4) then
        if not waitclic then
            if nearest and not starteddrag then
                savereserve-=1
                waitclic=true
                del(sensors,nearest)
                add(saveanim,nearest)
                nearest=nil
                sfx(9)
            else
                starteddrag=true
                if not pmb1 then
                    pmpx,pmpy=mpx,mpy
                end
                local mdist=1+max(abs(pmpx-mpx),abs(pmpy-mpy))
                for i=1,mdist do
                    local alpha=mdist>1 and (i-1)/(mdist-1) or 1
                    local cx,cy=lerp(pmpx,mpx,alpha),lerp(pmpy,mpy,alpha)
                    local size=max(1,min(3,flr(power/20)))
                    dig(cx,cy,size)
                end
            end
        end
        pmpx,pmpy=mpx,mpy
    else
        waitclic=false
        starteddrag=false
    end
    pmb1=mb1

        -- write to screen again
    poke(0x5f55,0x60)
   
    cls()
    -- copy spritesheet on the screen
    memcpy(0x6000,0,0x2000)
       
    -- particles
    local parttodel={}
    for i=1,#particles do
        local p=particles[i]
        p.x+=p.vx
        p.y+=p.vy
        p.vy+=.2
        pset(p.x,p.y,p.c)
        p.dur-=1
        if p.dur<0 then
            add(parttodel,p)
        end
    end
    for i=1,#parttodel do
        del(particles,parttodel[i])
    end

    local alive=0
    local dead=0
    local underwater=0
    for i=1,#sensors do
        local s=sensors[i]
        pset(s.x,s.y-1,15)
        pset(s.x,s.y,3)
        if s.dead then
            dead+=1
            line(s.x-2,s.y-2,s.x+2,s.y+2,8)
            line(s.x-2,s.y+2,s.x+2,s.y-2,8)
        else
            alive+=1
            if savereserve>0 then
                local basecol=nearest==s and 8 or 6
                circfill(s.x,s.y,3,basecol+flr(frame/10)%2)
            end
            if s.water>10 then
                circ(s.x,s.y,3,8+flr(frame/4)%2)
                underwater+=1
            end
            --print(s.water,s.x,s.y-6,8)
        end
    end
    if underwater>0 then
        if lastdrownsfx<1 then
            sfx(7)
            lastdrownsfx=10
        end
    end
    if frame==1000 then
        setmusic(1,true)
    end
    if frame==2000 then
        setmusic(2,true)
    end
       
    if alive==0 and not cheat then
        if not finish then
            finish=true
            setmusic(0,true)
            setmusic(1,false)
            setmusic(2,false)
            playmusic(-1,500)
           
            if #saveanim==0 then
                sfx(15)
            elseif dead>0 then
                sfx(14)          
            else
                sfx(13)
            end
        end
    end
   
    for i=1,#saveanim do
        local s=saveanim[i]
        if not s.saved then
            if #s.history>=s.hisanim then
                local cur=s.history[s.hisanim]
                local secondstep=true
                if s.hisanim==1 then
                    if s.x!=cur.x then
                        s.x+=max(-1,min(1,cur.x-s.x))
                        secondstep=false
                    end
                    if s.y>cur.y then
                        s.y-=1
                        secondstep=false
                    end
                end
                if secondstep then
                    s.x,s.y=cur.x,cur.y
                    s.hisanim+=1
                end
                if s.y<10 then
                    s.saved=true
                end
            end
            circfill(s.x,s.y,1.5,15)
            add(particles,{x=s.x,y=s.y,vx=(rnd(2)-1)*.2,vy=0,dur=20,c=6})
        end
    end
   
    if not finish then
   
        --print(#water,1,120,7)
        --print(flr(stat(1)*100),1,120,7)
   
        if nearest and not starteddrag then
            print("save?",nearest.x,nearest.y+5,8)
            drawmouse(mpx,mpy)
        else
   
            local mcolor=7
            if power<100 then mcolor=10 end  
            if power<40 then mcolor=9 end
            if power<10 then mcolor=8 end
       
            circ(mpx,mpy,3,mcolor)
           
        end
    end

    if finish then
   
        local mes="perfect!"
        if dead>0 then
            mes="bravo"
        end
        if #saveanim==0 then
            mes="total failure"
        end
   
        local py=32+finishtimer  
        printc(mes,64,py,7)
        printc("you saved",64,py+8,7)
        printc(#saveanim.." people",64,py+14,7)
       
        if dead>0 then
            printc(dead.." died",64,py+22,7)
        end
       
        if finishtimer>0 then
            finishtimer-=1
        else
            if btn(4) or btn(5) or mb1 then
                startedgame=false
                mainmenu=true
                frame=0
                playmusic(0,1000)
                -- the end
                reload(0,0,0x2000)
            end
            printc("press any button to quit",64,100,6+flr(frame/12)%2)
        end
    else
        printc("to save:"..alive,22,2,6)
        --print("save "..savereserve.." next "..savenext,1,7,6)
        gauge(80,2,45,power,maxpower,11)
        if savereserve>0 then
            printc("select person",102,5,6+flr(frame/10)%2)
        else
            gauge(80,6,45,savedelay-savenext,savedelay,7)
        end
       
        if savenext>0 then
            savenext-=1
        else
            savereserve=1
            savenext=savedelay
        end
    end
   
    -- [[
    local wintime=totalpeople*savedelay
    local totalpixel=128*118
    local totalfluid=wintime+max(0,wintime-sourcetime)+max(0,wintime-sourcetime*2)
    totalfluid-=flr(max(0,totalfluid-2500)/2)
    local totaldig=flr(powerstart+wintime*powergain)
    local estimspace=totalpixel/2+totaldig
    print("win time "..wintime,2,20,7)
    print("total pixel "..totalpixel,2,26,7)
    print("total fluid "..totalfluid,2,32,7)
    print("total dig "..totaldig,2,38,7)
    print("frame "..frame,2,44,7)
    print("water "..#water,2,50,7)  
    print("estimate space "..estimspace,2,56,7)  
    --]]--
       
    frame+=1
    if lastdigsfx>0 then
        lastdigsfx-=1
    end
    if lastdrownsfx>0 then
        lastdrownsfx-=1
    end
   
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
