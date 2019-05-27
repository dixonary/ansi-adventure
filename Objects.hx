package;
import haxe.Constraints;
import cpp.vm.Thread;
import ANSI;
using Objects;
using StringTools;
using Rooms;
using Lambda;

/*  Kitchen Objects */
class Key extends SmallObject {
    override function v_pickup(args)
        return super.v_pickup(args).concat(["It is heavy and made of metal.","You put it in your pocket."]);
    override function v_see(args) return ['There\'s ${hn.article()}${!taken?' on the table':''}.'];
    override function v_touch(args) return ['It feels cold and plot-relevant.'];
}

class Stove extends Object {
    override function v_see(args) return ['Over by the window is a small $hn.'];
}

class Table extends Object {}



/* Lounge objects */
class Piano extends Object {

    var proc:sys.io.Process;
    function v_use(args) {
        Thread.create(function() Sys.command("paplay $HOME/piano.ogg"));
        Game.runningEvent = this;
        return ['You start playing the $hn.','Unfortunately you can only remember one tune these days.'];
    }

    function v_stopEvent(args) {
        var rv = Sys.command("pkill paplay");
        return rv==0?['You stop playing the $hn.']:[];
    }

    function v_play(args) return v_use(args);
}

class Dresser extends Object {
    function v_move(args) {
        Game.currentRoom.objects.push(new Screwdriver());
        return ['You shift the $hn aside.', 'Something was underneath it.'];
    }
    function v_push(args) return v_move(args);
    override function v_touch(args) return ['It\'s dusty.'];
}
class Screwdriver extends SmallObject {
    override function v_see(args)
        return ['A small $hn is where the ${"dresser".h()} used to be.'];

    function v_useOn(args) {
        if(args[0] != "mirror") return null;
        Game.currentRoom.objects.push(World.hole);
        Game.currentRoom.objects.push(new Shards());
        Game.currentRoom.objects.remove(Game.currentRoom.objects.find(function(f) return f.name() == "mirror"));
        Game.inventory.remove(this);
        Game.currentRoom.objects.remove(this);
        return ['You unscrew the ${"mirror".h()} from the wall.',
                'It falls to the floor and shatters.',
                'There is a large ${"hole".h()} in the wall which was covered by the ${"mirror".h()}.',
                'The $hn breaks.'];
    }
}
class Shards extends Object {
    override function v_see(args) return ['There are ${"shards of glass".h()} all over the floor.'];
    override function v_look(args) return ['They look sharp.','You make a mental note not to tread on them.'];
}



/* Outdoor Objects */
class Fence extends Object {
    override function v_see(args) return ['A large $hn surrounds the courtyard you find yourself in.'];
    override function v_look(args) return ['The fence is ten foot high and topped with barbed wire.'];
    function v_climb(args) return cut();
    override function v_touch(args) return cut();

    function cut() {
        Effects.isCut = true;
        return ['You cut your hand on the sharp wire and fall back into the courtyard.'];
    }

}


/* Compactor objects */
class Button extends Object {

    override function v_look(args)     return ['The $hn is too high up to press by hand.'];
             function v_throwHit(args) {
                 new Hatch(Game.currentRoom, new Escape());
                 return ['A ${"hatch".h()} opened up near the floor!'];
             }
}

/* Bedroom Objects */
class Bed extends Object {
    function v_sit(args) return ['The $hn is hard and unforgiving.'];
    function v_lie(args) return ['You lay down.','You feel no better off.'];
    function v_use(args) return ['You sit on the $hn.'].concat(v_sit(args));
    override function v_see(args) return ['There\'s a $hn in the corner of the room.'];
}

class Mirror extends Object {
    override function v_see(args) return ['A $hn is on the opposite wall.'];
    override function v_look(args) return ['The $hn is screwed fast into the wall.','Wow, you do NOT look well.'];
    function v_throwHit(args) return ['It makes a loud noise but doesn\'t shatter.'];
    function v_use(args) return v_look(args);
}




/* Generic object definitions */

class SmallObject extends Object {
    var taken:Bool = false;

    function v_throw(args:Array<String>) {
        if(args.length > 1) {
            for(o in Game.currentRoom.objects) {
                if(o.name() == args[1]) {
                    v_drop(args);
                    var k = o.action("throwHit",[o.name()]);
                    if(k == null) k = [];
                    return ['You throw the $hn at the ${o.name().h()}.']
                        .concat(k);
                }
            }
            return ['There\'s no ${args[1].h()} to hit!'];
        }
        else {
            Game.inventory.remove(this);
            Game.currentRoom.objects.push(this);
            return ['You throw the $hn.'];
        }
    }

    function v_inventory(args:Array<String>) {
        return ['You have a $hn.'];
    }

    function v_pickup(args:Array<String>) {
        if(Game.inventory.indexOf(this) != -1)
            return ['You already have the $hn.'];
        taken=true;
        Game.inventory.push(this);
        Game.currentRoom.objects.remove(this);
        return ['You pick up the $hn.'];
    }

    function v_drop(args:Array<String>) {
        Game.inventory.remove(this);
        Game.currentRoom.objects.push(this);
        return ['You drop the $hn.'];
    }
}

class Object {

    var aliases:Array<Array<String>>=[];
    public var hn(get,never):String;

    public function get_hn():String return name().h();

    public function new() {
        aliases.push(["look","inspect","ls"]);
        aliases.push(["pickup", "take", "steal", "pick"]);
        aliases.push(["walk","go", "enter"]);
        aliases.push(["throw", "lob", "chuck"]);
        aliases.push(["lie","lay"]);
        aliases.push(["move","shift"]);
        aliases.push(["push","press"]);
        aliases.push(["climb","clamber"]);
        aliases.push(["touch", "poke"]);
    }

    public function action(verb:String, args:Array<String>)
            :Null<Array<String>> {
        var v:String="";
        // Use aliased word if one exists
        for(aset in aliases) {
            if(aset.indexOf(verb) != -1) {
                v = aset[0];
                break;
            }
        }
        // Otherwise just use the current one
        if(v == "") {
            v = verb;
        }

        if(this.supports(v))
            return Reflect.callMethod(this,Reflect.field(this,'v_$v'), [args]);
        else
            return null;

    }

    function v_touch(args:Array<String>) {
        return ['You touch the $hn.'];
    }
    function v_look(args:Array<String>) {
        return ['It\'s ${article(hn)}.'];
    }

    function v_see(args:Array<String>) {
        return ['There is ${article(hn)}.'];
    }

    function v_walk(args:Array<String>)
        return ['You walk up to the ${name()}.'];

    /* Helper Functions */
    public static function article(word:String) {
        var w2 = (word.charCodeAt(0)==27?word.substr(6):word).split("");
        var first = w2.find(function(w) return "abcdefghijklmnopqrstuvwxyz".indexOf(w) != -1);
        return 'a${"aeiou".indexOf(first)!=-1?"n":""} $word';
    }

    public static function name(o:Object) {
        var k = Reflect.getProperty(o,'customName');
        if(k!=null) return k;
        return Type.getClassName(Type.getClass(o)).toLowerCase();
    }

    public static function h(s:String)
        return Game.hlColor + s + Game.inputColor;

    public static function supports(o:Object, action:String) {
        return Reflect.field(o, 'v_$action') != null;
    }

}

