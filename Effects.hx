package;

using Lambda;
using StringTools;
import ANSI;
using Rooms;

class Effects {

    /* Helper variables */
    public static var TICKRATE:Float = 1/10;
    public static var game:Game;
    public static var screenW(get,never):Int;
    public static var screenH(get,never):Int;

    /* Snow effect */
    public static var snowing:Bool     = false;
    public static var snowAmount:Float = 0;
    public static var snow:Array<Snow> = [];


    /* Water effect */
    public static var water:Array<Water>= [];
    public static var waterLevel:Float  = -0.05;
    public static var waterTarget:Float = -0.05;
    public static var NUM_WAVES:Int     = 5;
    public static var waves:Array<Sine> = [];
    public static var droplets:Array<Droplet> = [];
    public static var waveOffset:Float  = 0;

    /* Cut effect */
    public static var isCut:Bool = false;

    /* Crusher speed */
    public static var crusherSpeed:Float = 0;
    public static var crusherSize:Float = 0;


    static public function get_screenW():Int return game.screenW - Std.int(crusherSize);
    static public function get_screenH():Int return game.screenH;

    static public function resize() {
        var proc = new sys.io.Process("resize", []);
        var output = proc.stdout.readAll().toString().split("\n").slice(0,2);
        proc.close();
        output=output.map(function(s) return s.split("=")[1].replace(";",""));
        game.screenW = Std.parseInt(output[0]);
        game.screenH = Std.parseInt(output[1]);
    }

    static public function tick() {

        Sys.print(ANSI.saveCursor());

        Sys.print(ANSI.setXY(screenW, screenH) + ANSI.eraseDisplayToCursor());

        runWater();

        game.writeInput();
        game.writeHistory();

        runSnow();

        runCut();
        runCrusher();

        Sys.print(ANSI.loadCursor());

    }

    static function overlapSines(x) {
        return waves.fold(function(w,n)
            return n+Math.sin(x*w.sstr+waveOffset*w.soff)
        ,0)/waves.length;
    }
    static function runWater() {
        if(waterLevel < waterTarget) waterLevel += 0.003;
        if(waterLevel > waterTarget) waterLevel -= 0.003;

        if(waterLevel > -0.05) {

            for(n in 0...water.length) {
                var pos = overlapSines(n);
                water[n].level = (1-waterLevel) + pos*0.075;
            }

            Sys.print(ANSI.set(BlueBack));
            for(x in 0...water.length)
                for(y in Std.int(water[x].level*screenH)+1 ... screenH+1)
                    Sys.print(ANSI.setXY(x,y) + " ");



            for(d in droplets) {
                var k = (Math.random() + (d.y/screenH))*1.5;
                while(k-->0.5)
                    d.y++;
                if(d.y>=screenH) {
                    droplets.remove(d);
                    new sys.io.Process("paplay $HOME/drip.wav");
                }
            }
            if(Math.random() < 0.05)
                droplets.push({x:Math.floor(Math.random()*screenW), y:0});


            for(d in droplets)
                Sys.print(ANSI.setXY(d.x,d.y) + " ");


            waveOffset+=0.2;

        }

    }

    static function runCrusher() {
        crusherSize+=crusherSpeed;
        crusherSize = Math.max(crusherSize, 0);
        Sys.print(ANSI.set(WhiteBack));
        for(x in screenW ... (screenW+Std.int(crusherSize)))
            for(y in 0 ... screenH) {
                Sys.print(ANSI.setXY(x,y) + " ");
            }
        if(screenW <= 1) {
            Game.currentRoom = new EndRoom();
        }
    }

    static function runCut() {
        if(!isCut) return;
        var offset=screenH;
        Sys.print(ANSI.set(RedBack));
        for(i in screenW-offset ... screenW) {
        Sys.print(ANSI.setXY(i-1, i-(screenW-offset)));
            Sys.print("   ");
        }
    }

    static function runSnow() {
        Sys.print(ANSI.set(Bold,White));

        for(s in snow) {
            if(Math.random() < 0.3)
                s.x++;
            if(Math.random() < 0.5)
                s.y++;
            if(s.x == screenW+1 || s.y == screenH+1)
                snow.remove(s);
        }

        if(snowing) {
            var k = snowAmount+1;
            while(k --> 0) {
                if(Math.random() < k) {
                    if(Math.random() < (screenW / (screenW + screenH)))
                        snow.push({x:Math.floor(Math.random()*screenW), y:0});
                    else
                        snow.push({y:Math.floor(Math.random()*screenH), x:0});
                }
            }
        }

        for(s in snow) {
            Sys.print(ANSI.setXY(s.x,s.y) + "█");
        }

    }

    static public function effectsThread() {

        /* Initialise water */
        var offset = 0;
        for(i in 0...NUM_WAVES) {
            var sineOffset = -Math.PI + 2*Math.PI*Math.random();
            var sineAmp    = Math.random() * 0.1;
            var sineStr    = Math.random() * 0.25;
            var offStr     = 0;
            waves.push({soff:sineOffset, samp:sineAmp, sstr:sineStr, offs:offStr});
        }
        for(i in 0 ... screenW) {
            water.push({pixel:i,speed:0,mass:1,level:0});
        }


        var time;
        while(true) {
            time = Sys.time();
            tick();
            Sys.sleep(TICKRATE-Sys.time()+time);
        }

    }

    static public function clearEffects() {
        snow = [];
        Sys.print(ANSI.setXY(screenW, screenH-1) + ANSI.eraseDisplayToCursor());
    }


}

typedef Snow = {
    x:Int,
    y:Int
}

typedef Sine = {
    soff:Float,
    samp:Float,
    sstr:Float,
    offs:Float
}

typedef Water = {
    pixel:Int,
    speed:Float,
    mass:Float,
    level:Float
}

typedef Droplet = {
    x:Int,
    y:Int
}
