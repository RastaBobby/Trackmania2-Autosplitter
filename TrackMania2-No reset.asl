state("ManiaPlanet32") {}
state("ManiaPlanet") {}

startup
{
    // Memory stuff
    vars.Watchers = new MemoryWatcherList();
    vars.TryInit = (Func<Process, ProcessModuleWow64Safe, bool>)((gameProc, module) =>
    {
        var loadingTarget = (gameProc.Is64Bit())
            ? new SigScanTarget(9, "83 3D ?? ?? ?? ?? ?? 8B 05 ?? ?? ?? ??")
            : new SigScanTarget(9, "51 83 3D ?? ?? ?? ?? ?? A1 ?? ?? ?? ??");

        // 0x14097DA40, 0x1145C00
        var raceStateTarget = (gameProc.Is64Bit())
            ? new SigScanTarget(8, "56 48 83 EC 30 48 8B 05 ?? ?? ?? ?? 41 8B F1")
            : new SigScanTarget(38, "56 8B F1 E8 ?? ?? ?? ?? 8B 8E ?? ?? ?? ?? 85 C9 74 36");

        // 0x14014D770, 0x52F3F0
        var loadMapTarget = (gameProc.Is64Bit())
            ? new SigScanTarget(52, "40 53 48 83 EC 30 48 C7 44 24 ?? ?? ?? ?? ?? 48 8B D9 B9 ?? ?? ?? ?? 65 48 8B 04 25 ?? ?? ?? ?? 48 8B 10 8B 04 11 39 05 ?? ?? ?? ?? 7F 23")
            : new SigScanTarget(59, "55 8B EC 6A FF 68 ?? ?? ?? ?? 64 A1 ?? ?? ?? ?? 50 A1 ?? ?? ?? ?? 51 33 C5 50 8D 45 F4 64 A3 ?? ?? ?? ?? 64 A1 ?? ?? ?? ??");

        // 0x14014F13E, 0x531163
        var gameInfoTarget = (gameProc.Is64Bit())
            ? new SigScanTarget(3, "48 89 05 ?? ?? ?? ?? 89 3D ?? ?? ?? ?? 48 8D 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 90 48 8D 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? E9 ?? ?? ?? ??")
            : new SigScanTarget(1, "B9 ?? ?? ?? ?? E8 ?? ?? ?? ?? A1 ?? ?? ?? ?? C6 04 38 00");

        loadingTarget.OnFound = (proc, _, ptr) =>
        {
            print("[ASL] loadingTarget = 0x" + ptr.ToString("X"));
            if (proc.Is64Bit())
            {
                var temp = 0;
                return proc.ReadValue<int>(ptr, out temp) ? (IntPtr)((long)temp + (long)ptr + 4) : IntPtr.Zero;
            }
            return proc.ReadPointer(ptr, out ptr) ? ptr : IntPtr.Zero;
        };
        raceStateTarget.OnFound = (proc, _, ptr) =>
        {
            print("[ASL] raceStateTarget = 0x" + ptr.ToString("X"));
            if (proc.Is64Bit())
            {
                var temp = 0;
                return proc.ReadValue<int>(ptr, out temp) ? (IntPtr)((long)temp + (long)ptr + 4) : IntPtr.Zero;
            }
            return proc.ReadPointer(ptr, out ptr) ? ptr : IntPtr.Zero;
        };
        loadMapTarget.OnFound = (proc, _, ptr) =>
        {
            print("[ASL] loadMapTarget = 0x" + ptr.ToString("X"));
            if (proc.Is64Bit())
            {
                var temp = 0;
                return proc.ReadValue<int>(ptr, out temp) ? (IntPtr)((long)temp + (long)ptr + 4) : IntPtr.Zero;
            }
            return proc.ReadPointer(ptr, out ptr) ? ptr : IntPtr.Zero;
        };
        gameInfoTarget.OnFound = (proc, _, ptr) =>
        {
            print("[ASL] gameInfoTarget = 0x" + ptr.ToString("X"));
            if (proc.Is64Bit())
            {
                var temp = 0;
                return proc.ReadValue<int>(ptr, out temp) ? (IntPtr)((long)temp + (long)ptr + 4) : IntPtr.Zero;
            }
            return proc.ReadPointer(ptr, out ptr) ? ptr : IntPtr.Zero;
        };

        var scanner = new SignatureScanner(gameProc, module.BaseAddress, module.ModuleMemorySize);
        var loadingPtr = scanner.Scan(loadingTarget);
        var raceStatePtr = scanner.Scan(raceStateTarget);
        var loadMapPtr = scanner.Scan(loadMapTarget);
        var gameInfoPtr = scanner.Scan(gameInfoTarget);

        print("[ASL] loadingPtr = 0x" + loadingPtr.ToString("X"));
        print("[ASL] raceStatePtr = 0x" + raceStatePtr.ToString("X"));
        print("[ASL] loadMapPtr = 0x" + loadMapPtr.ToString("X"));
        print("[ASL] gameInfoPtr = 0x" + gameInfoPtr.ToString("X"));

        if ((loadingPtr != IntPtr.Zero)
            && (raceStatePtr != IntPtr.Zero)
            && (loadMapPtr != IntPtr.Zero)
            && (gameInfoPtr != IntPtr.Zero))
        {
            print("[ASL] Scan Completed!");

            var dpLoadMap = new DeepPointer(module.ModuleName, (int)((long)loadMapPtr - (long)module.BaseAddress), 0);
            var dpGameInfo = new DeepPointer(module.ModuleName, (int)((long)gameInfoPtr - (long)module.BaseAddress), 0);

            vars.LoadingState = new MemoryWatcher<bool>(loadingPtr);
            vars.RaceState = new MemoryWatcher<int>(new DeepPointer(module.ModuleName, (int)((long)raceStatePtr - (long)module.BaseAddress), 0x28, 0xE8));
            vars.LoadMap = new StringWatcher(dpLoadMap, ReadStringType.ASCII, 128);
            vars.GameInfo = new StringWatcher(dpGameInfo, ReadStringType.ASCII, 128);

            vars.Watchers.Clear();
            vars.Watchers.AddRange(new MemoryWatcher[]
            {
                vars.LoadingState,
                vars.RaceState,
                vars.LoadMap,
                vars.GameInfo
            });
            vars.Watchers.UpdateAll(gameProc);

            print("[ASL] LoadingState = " + vars.LoadingState.Current);
            print("[ASL] RaceState = " + vars.ERaceState[vars.RaceState.Current]);
            print("[ASL] LoadMap = " + vars.LoadMap.Current);
            print("[ASL] GameInfo = " + vars.GameInfo.Current);
            return true;
        }
        print("[ASL] Scan Failed!"); 
        return false;
    });
    vars.ERaceState = new Dictionary<int, string>()
    {
        { 0, "BeforeStart" },
        { 1, "Running" },
        { 2, "Finished" },
        { 3, "Eliminated" },
    };

    vars.StartMaps = new List<string>() {"LoadMap '$fff$sA01'","LoadMap '$fff$sB01'","LoadMap '$fff$sC01'","LoadMap '$fff$sD01'","LoadMap '$fff$sE01'"};

    // Settings
    settings.Add("SplitOnMapChange", false, "Auto split on map change.");
    settings.Add("SmartSplit", false, "Auto split detection for unofficial maps.");
    settings.Add("SplitOnMapFinish", true, "Auto split when finishing a map.");

    for (int i = 0; i < 5; i++)
    {
        var cat = (i == 0) ? "White Flag" : (i == 1) ? "Green Flag" : (i == 2) ? "Blue Flag" : (i == 3) ? "Red Flag" : "Black Flag";
        settings.Add(cat, true, cat, "SplitOnMapFinish");
        for (int j = 1; j <= 15; j++)
        {
            if ((j > 5) && (i == 4))
                goto done;
            var map = string.Format("LoadMap '$fff$s{0}{1}'", (char)(i + 65), j.ToString("D2"));
            settings.Add(map, true, map.Substring(15, 3), cat);
        }
    }
done:

    // Others
    vars.GameRestart = false;
    vars.StartedMap = string.Empty;
}

init
{
    vars.Init = false;
    vars.Module = modules.First(module => module.ModuleName == ((game.Is64Bit()) ? "ManiaPlanet.exe" : "ManiaPlanet32.exe"));
}

update
{
    if (timer.CurrentPhase == TimerPhase.NotRunning)
    {
        vars.GameRestart = false;
        vars.StartedMap = string.Empty;
    }

    if (vars.Init)
    {    
        vars.Watchers.UpdateAll(game);

        // Rescan when titlepack is loading
        if ((string.IsNullOrEmpty(vars.GameInfo.Current))
            || (vars.GameInfo.Current.StartsWith("[Maniaplanet]"))
            || (vars.GameInfo.Current.StartsWith("[Game] exec MenuResult: 58"))
            || (vars.GameInfo.Current.Contains("loading title")))
        {
            print("[ASL] TP Rescan!");
            vars.TryInit(game, vars.Module);
        }

        // Unpause timer when titlepack has loaded
        if ((vars.GameRestart)
            && (vars.GameInfo.Current.StartsWith("[Game] main menu"))
            && (vars.GameInfo.Old.StartsWith("[Game] Loading title")))
        {
            print("[ASL] Unpaused GameTime!");
            timer.IsGameTimePaused = false;
            vars.GameRestart = false;
        }

        // Some debug info :^)
        if (vars.LoadingState.Changed)  print("[ASL] LoadingState Changed! (" + vars.LoadingState.Current + ")");
        if (vars.LoadMap.Changed)       print("[ASL] LoadMap Changed! (" + vars.LoadMap.Current + ")");
        if (vars.RaceState.Changed)     print("[ASL] RaceState Changed! (" + vars.ERaceState[vars.RaceState.Current] + ")");
        if (vars.GameInfo.Changed)      print("[ASL] GameInfo Changed! (" + vars.GameInfo.Current + ")");
    }
    else
    {
        print("[ASL] Default Scan!");
        return vars.Init = vars.TryInit(game, vars.Module);
    }
}

isLoading
{
    return (vars.LoadingState.Current) || (vars.GameRestart);
}

start
{

    if ((vars.LoadingState.Old) && (!vars.LoadingState.Current))
    {
        if (vars.StartMaps.Contains(vars.LoadMap.Current) && !settings["SmartSplit"])
            return true;

        // Used for SmartSplit auto reset
        if (settings["SmartSplit"])
        {
            print("[ASL] StartedMap = " + vars.LoadMap.Current);
            vars.StartedMap = vars.LoadMap.Current;
            return true;
        }
    }
    return false;
}

split
{
    // Map change
    if ((settings["SplitOnMapChange"]) && (vars.LoadMap.Old != vars.LoadMap.Current))
        return true;

    // Finish line
    if ((vars.RaceState.Old == 1) && (vars.RaceState.Current == 2) && (!vars.LoadingState.Current))
    {
        print("[ASL] Detected Finish!");
        // End of nadeo map
        if (settings[vars.LoadMap.Current])
            return true;
        else if (settings["SmartSplit"])
            return true;

        // End of category
        switch (vars.GetCategory() as string)
        {
            case "White":
                return vars.LoadMap.Current == "LoadMap '$fff$sA15'";
            case "Green":
                return vars.LoadMap.Current == "LoadMap '$fff$sB15'";
            case "Blue":
                return vars.LoadMap.Current == "LoadMap '$fff$sC15'";
            case "Red":
                return vars.LoadMap.Current == "LoadMap '$fff$sD15'";
            case "Black":
            case "All Flags":
                return vars.LoadMap.Current == "LoadMap '$fff$sE05'";
        }
    }
    return false;
}

exit
{
    if ((timer.CurrentPhase == TimerPhase.Running) || (timer.CurrentPhase == TimerPhase.Paused))
    {
        print("[ASL] Paused GameTime!");
        timer.IsGameTimePaused = true;
        vars.GameRestart = true;
    }
}