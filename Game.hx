import cpp.vm.Thread;
import ANSI;
using Lambda;
using StringTools;
import Objects;
using Objects;
import Rooms;

class Game {

    public var screenW:Int = 0;
    public var screenH:Int = 0;

    var input:String = "";
    public static var history:Array<Array<String>> = [];

    public static var historyColor = ANSI.set(BoldOff, White);
    public static var inputColor   = ANSI.set(Bold, White) + ANSI.set(DefaultBackground);
    public static var hlColor      = ANSI.set(BoldOff, Yellow);
    public static var currentRoom(default,set):Room;

    public static var runningEvent:Object = null;

    public static var inventory:Array<SmallObject> = [];

    public function new() {

        /* Get output from Resize and interpret as screen size */

        Effects.game = this;
        var proc = new sys.io.Process("resize", []);
        var output = proc.stdout.readAll().toString().split("\n").slice(0,2);
        proc.close();
        output=output.map(function(s) return s.split("=")[1].replace(";",""));
        screenW = Std.parseInt(output[0]);
        screenH = Std.parseInt(output[1]);
        Thread.create(Effects.effectsThread);

        currentRoom = new World().startingRoom;
        history.push([""].concat(currentRoom.action("look",[])));

        Sys.sleep(0.01);
        while(true) {
            stepLogic();
        }
    }

    public function stepLogic() {

        writeInput();
        var k = ""+String.fromCharCode(Sys.getChar(false));

        if(k == "" || k == "") {
            exit();
        }
        else if(k == "") {
            Effects.resize();
            var newH = [];
            newH.push("> " + input);
            newH = parseCommand(input.trim(), newH);
            input = "";
            history.push(newH);
            Sys.print(ANSI.eraseLine());
        }
        else if(k == "") {
            input = input.substr(0,input.length-1);
            Sys.print(ANSI.moveLeft(1) + ANSI.deleteChar());
        }
        else {
            var c = k.charCodeAt(0);
            if(c>=65 && c<=90) c+=32;
            if((c >= 97 && c <= 122) || c == 32 || (c>=48&&c<=57)) {
                input += String.fromCharCode(c);
            }
        }
    }

    public function writeInput() {
        Sys.print(inputColor + ANSI.setXY(0,screenH) + "> "
                + input + ANSI.setXY(input.length+3, screenH));
    }

    public function writeHistory() {
        var line = screenH;
        for(i in 0 ... history.length) {
            var h = history.length-i-1;
            if(history[h].length>1) line--;
            if(line <= 0) return;

            for(j in 0 ... history[h].length) {
                var k = history[h].length-j-1;

                var helem = history[h][k];

                //number of lines taken up by the latest history element to consider
                var numLines = Math.ceil(helem.length / screenW);
                line -= numLines;
                if(line <= 0) return;
                Sys.print(ANSI.setXY(0,line) + (k!=0?inputColor:historyColor) + helem);
            }
        }
    }

    function parseCommand(cmd:String, response:Array<String>):Array<String> {
        var nothings = [
            "a","an","the","that","to","from",
            "on","for","at","around","up", "through", "down", "into", "my"
        ];
        var cmd_split = cmd.split(" ").filter(
                function(s) return nothings.indexOf(s) == -1);
        var verb = cmd_split[0];
        var args = cmd_split.slice(1);

        if(runningEvent != null) {
            response = response.concat(runningEvent.action("stopEvent",[]));
            runningEvent = null;
        }
        /* EFFECTS */
        if(verb == "snow") {
            if(args.length > 0) {
                var x = Std.parseInt(args[0]);
                if(x != null && x > 0) {
                    Effects.snowing = true;
                    Effects.snowAmount = x/100;
                    response.push('It is snowing.');
                }
            }
            else if(Effects.snowing) {
                    Effects.snowing = false;
                    response.push('It is no longer snowing.');
            }
            else
                response.push("But how much?");
        }
        else if(verb == "water") {
            if(args.length > 0) {
                var x = Std.parseInt(args[0]);
                if(x != null && x >= 0) {
                    Effects.waterLevel = x/100;
                }
            }
            else if(Effects.waterLevel > 0) {
                    Effects.waterLevel = 0;
            }
        }

        /* HELPERS */
        else if(verb == "clear") {
            history = [];
        }
        else if(verb == "exit" || verb == "quit") {
            exit();
        }

        else if(["i","inv","inventory","pocket","pockets"].indexOf(verb) != -1) {
            response = response.concat(inv());
        }
        else {
            var resp = (currentRoom.action(verb, args));
            if(resp != null) response = response.concat(resp);
        }
        return response;
    }

    public static function inv():Array<String> {
        if(inventory.length == 0) return ['You have nothing in your pockets.'];
        return inventory.fold(function(s,o:Array<String>) return o.concat(s.action("inventory",[])),[]);
    }

    function exit() {
        Effects.clearEffects();
        writeHistory();
        writeInput();
        Sys.exit(0);
    }

    static public function set_currentRoom(r:Room) {
        if(currentRoom != null)
        currentRoom.leaveRoom();
        r.enterRoom();
        return currentRoom = r;
    }

}
