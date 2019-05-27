import Objects;
using Objects;
using Lambda;

class World {
    public var startingRoom:Room;

    public static var hole:Hole;

    public function new() {
        var bedroom = new Bedroom();
        var kitchen = new Kitchen();
        var lounge = new Lounge();
        var tunnel = new Tunnel();
        var outside = new Outside();
        var crusher = new Crusher();
        new Door(bedroom, kitchen);
        new Archway(kitchen, lounge);
        new Manhole(tunnel,outside);
        new Chute(outside, crusher);

        hole = new Hole(bedroom, tunnel);

        startingRoom = bedroom;
    }
}

/* Room definitions */

class Bedroom extends Room {

    public function new() {
        super();
        description = ['You are in a $hn.', "It's sparsely decorated."];
        objects = [new Bed(), new Mirror()];
    }

}

class Outside extends Room {

    public function new() {
        super();
        description = ['It\'s cold and snowing outside.'];
        objects = [new Fence()];
    }

    override public function enterRoom() {
        Effects.snowing = true;
        Effects.snowAmount = 1;
    }
    override public function leaveRoom() {
        Effects.snowing = false;
    }

}


class Kitchen extends Room {

    public function new() {
        super();
        description = ['This $hn isn\'t really much better than the bedroom.'];
        objects = [new Stove(), new Table(), new Key()];
    }

}

class Tunnel extends Room{
    public function new() {
        super();

        description = ['This $hn is dark and there is ankle-deep water in here.','Water is dripping from the roof.','No wonder your bedroom was always so cold.'];
    }

    override public function enterRoom() { Effects.waterTarget = 0.1; }
    override public function leaveRoom() { Effects.waterTarget = -0.05;   }
}

class Lounge extends Room {

    public function new() {
        super();
        description = ['You walk through into a small $hn.'];
        objects = [new Piano(), new Dresser()];
    }

    override function v_look(args) {
        var res = super.v_look(args);
        description = ['The $hn is shabby and clearly hasn\'t been updated in many years.'];
        return res;
    }
}

class Crusher extends Room {

    public function new() {
        super();
        description = ['This is a trash compactor!','The walls are closing in!'];
        objects = [new Button()];
    }
    override public function enterRoom() { Effects.crusherSpeed = 0.3; }
    override public function leaveRoom() { Effects.crusherSpeed = -2;  }

}

class Escape extends Room {
    public function new() {
        super();
        description = ['You made it out alive.','The game is over.'];
    }
}

class EndRoom extends Room {
    override public function enterRoom() { Game.history.push(['','You died.']);}
    override public function new() {
       super();
       description = ['You\'re in the afterlife.','Bad luck.'];
    }
}

class Hatch extends Door {
    override public function v_look(args) return ['Freedom! You can fit through the $hn.'];
    override public function new(loc1,loc2) {
        super(loc1,loc2);
        loc2.objects.remove(this);
    }
}

class Chute extends Door {
    override function v_walk(args) {
        if(Game.currentRoom == loc1)
            return super.v_walk(args);
        else
            return ['It\'s too steep!'];
    }

    override function v_look(args) {
        if(Game.currentRoom == loc1)
            return ['Is that a glimmer of light at the bottom?'];
        else
            return super.v_look(args);
    }

    function v_climb(args) return v_use(args);
}


class Archway extends Door {
    override function v_see(args)
        return ['A wide $hn leads through to ${used?'the '+other.hn:other.hn.article()}.'];
}


class Hole extends Door {
    var customName(get,never):String;

    public function new(loc1, loc2) {
        super(loc1,loc2);
        loc1.objects.remove(this);
    }

    function get_customName()
        return Game.currentRoom==loc1?"hole":"stairway";

    override function v_walk(args) {
        var wasUsed = used;
        traverse();
        return wasUsed?
            ['You climb ${other==loc1?"down":"up"} the stairs and back into the ${Game.currentRoom.hn}.']:
            ['The hole leads to a set of stairs.','You climb down them and find yourself in a ${Game.currentRoom.hn}.'];
    }

    function v_climb(args) return v_use(args);
}

class Manhole extends Door {

    var customName(get,never):String;

    function get_customName()
        return Game.currentRoom==loc1?"ladder":"manhole";

    override function v_walk(args) {
        var wasUsed = used;
        traverse();
        return ['You climb ${other==loc1?"up":"down"} the ${"ladder".h()} and find yourself ${wasUsed?"back ":""}${Game.currentRoom.name()=="outside"?"outside".h():'in the ${"tunnel".h()}'}.'];
    }

    override function v_look(args) {
        if(other.name() == "outside")
            return ['It leads ${other.hn}.'];
        else
            return ['It leads to the ${other.hn}.'];
    }

    function v_climb(args) return v_use(args);

}



/* Generic definitions */

class Door extends Object {

    var loc1:Room;
    var loc2:Room;
    public var other(get,never):Room;
    var used:Bool = false;
    public function new(l1, l2) {
        super();
        loc1 = l1; loc2 = l2;
        loc1.objects.push(this);
        loc2.objects.push(this);
    }

    function get_other() return Game.currentRoom==loc1?loc2:loc1;

    function traverse() {
        used = true;
        Game.currentRoom = other;
    }

    override function v_walk(args) {
        var u = used;
        var o = other;
        traverse();
        return ['You go through the $hn${u?' into the ${o.hn}':''}.']
            .concat(u?[]:o.action("look",[]));
    }

    override function v_see(args)
        return used?['There is a $hn which leads back to the ${other.hn}.']:super.v_see(args);

    function v_use(args) return v_walk(args);
    override function v_look(args) return used?seenAlready():unseen();

    function seenAlready() return ['It leads back to the ${other.hn}.'];
    function unseen() return ['It seems to lead to ${other.hn.article()}.'];

}

class Room extends Object {

    public var objects:Array<Object> = [];
    public var description:Array<String> = ["You\'re in a room."];

    override public function action(verb:String, args:Array<String>) {

        var allObjects = objects.copy();
        for(i in Game.inventory) allObjects.push(i);
        if(verb=="go" && args.length>0) {
            for(o in allObjects){
                try {
                var o2 = cast(o,Door);
                if(o2.other.name() == args[0]) return o2.action("go",args);
                }
                catch(e:Dynamic){};
            }
        }

        else if(verb == "use") {
            if(args.length == 0)
                return ['Use what?']
            else if(args.length >= 2) {
                var o1 = allObjects.find(function(o) return o.name() == args[0]);
                var o2 = allObjects.find(function(o) return o.name() == args[1]);
                if(o1 == null) return ['You can\'t see ${args[0].h().article()}.'];
                if(o2 == null) return ['You can\'t see ${args[1].h().article()}.'];

                var resp = o1.action("useOn",args.slice(1));
                if(resp == null)
                    return ['You can\'t $verb the ${o1.hn} like that.'];
                else return resp;
            }
        }

        if(args.length>0) {
            if(args[0] == name()) return action(verb, args.slice(1));
            for(o in allObjects)
            if(o.name() == args[0]) {
                var resp = o.action(verb, args);
                if(resp == null)
                    return ['You can\'t $verb the ${args[0].h()}.'];
                else return resp;
            }

            return ['You can\'t see ${args[0].h().article()}.'];
        }

        return super.action(verb, args);
    }

    override function v_look(args:Array<String>) {

        var resp = [];
        if(args.length>0) {
            for(o in objects)
            if(o.name() == args[0])
                return o.action("look",args);


            return resp.concat(['You can\'t see ${args[0].h().article()}.']);
        }

        resp=resp.concat( objects.fold(function(o:Object,k:Array<String>)
            return k.concat(o.v_see(args)), description)
        );

        return resp;
    }

    override function v_see(args) return v_look(args);
    override function v_walk(args) return ['Where?'];
    override function v_touch(args) return ['Touch what?'];

    //called when a room is left.
    public function leaveRoom() {};
    public function enterRoom() {};

}
