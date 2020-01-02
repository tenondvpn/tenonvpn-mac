//
//  BGUtils.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/6.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Foundation
import libp2p

let SS_LOCAL_VERSION = "3.2.5"
let KCPTUN_CLIENT_VERSION = "v20190905"
let V2RAY_PLUGIN_VERSION = "1.1.0"
let PRIVOXY_VERSION = "3.0.26.static"
let SIMPLE_OBFS_VERSION = "0.0.5_1"
let APP_SUPPORT_DIR = "/Library/Application Support/ShadowsocksX-NG/"
let USER_CONFIG_DIR = "/.ShadowsocksX-NG/"
let LAUNCH_AGENT_DIR = "/Library/LaunchAgents/"
let LAUNCH_AGENT_CONF_SSLOCAL_NAME = "com.qiuyuzhou.shadowsocksX-NG.local.plist"
let LAUNCH_AGENT_CONF_PRIVOXY_NAME = "com.qiuyuzhou.shadowsocksX-NG.http.plist"
let LAUNCH_AGENT_CONF_KCPTUN_NAME = "com.qiuyuzhou.shadowsocksX-NG.kcptun.plist"
let iCon:[String] = ["us", "sg", "br","de","fr","kr", "jp", "ca","au","hk", "in", "gb","cn"]
let defaultRoute:[String] = ["US", "DE", "IN", "CA", "AU"]
let queue = DispatchQueue(label: "refresh_config_route_node")
var server_stoped_by_user = false

func getFileSHA1Sum(_ filepath: String) -> String {
    if let data = try? Data(contentsOf: URL(fileURLWithPath: filepath)) {
        return data.sha1()
    }
    return ""
}

// Ref: https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
// Genarate the mac launch agent service plist

//  MARK: sslocal

func generateSSLocalLauchAgentPlist() -> Bool {
    let sslocalPath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-latest/tenon_local"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/ss-local.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_SSLOCAL_NAME
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    
    let defaults = UserDefaults.standard
    let enableUdpRelay = defaults.bool(forKey: "LocalSocks5.EnableUDPRelay")
    let enableVerboseMode = defaults.bool(forKey: "LocalSocks5.EnableVerboseMode")
    
    var arguments = [sslocalPath, "-c", "ss-local-config.json", "--fast-open"]
    if enableUdpRelay {
        arguments.append("-u")
    }
    if enableVerboseMode {
        arguments.append("-v")
    }
    arguments.append("--reuse-port")
    
    // For a complete listing of the keys, see the launchd.plist manual page.
    let dyld_library_paths = [
        NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-latest/",
        NSHomeDirectory() + APP_SUPPORT_DIR + "plugins/",
        ]
    
    let dict: NSMutableDictionary = [
        "Label": "com.qiuyuzhou.shadowsocksX-NG.local",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments,
        "EnvironmentVariables": ["DYLD_LIBRARY_PATH": dyld_library_paths.joined(separator: ":")]
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    
    print("plist file sha1sum old:\(oldSha1Sum), now: \(Sha1Sum)")
    if oldSha1Sum != Sha1Sum {
        return true
    } else {
        return false
    }
}

func getOneRouteNode_ex(country: String) -> (ip: String, port: String) {
    let res_str = LibP2P.getVpnNodes(country, true) as String
    if (res_str.isEmpty) {
        return ("", "")
    }
    
    let node_arr: Array = res_str.components(separatedBy: ",")
    if (node_arr.count <= 0) {
        return ("", "")
    }
    
    let rand_pos = randomCustom(min: 0, max: node_arr.count)
    let node_info_arr = node_arr[rand_pos].components(separatedBy: ":")
    if (node_info_arr.count < 5) {
        return ("", "")
    }
    
    return (node_info_arr[0], node_info_arr[2])
}

func initRouteNode() -> (ip: String, port: String) {
    return ("", "")
}

func StartSSLocal() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "start_ss_local.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        server_stoped_by_user = false
        queue.async {
            while (!server_stoped_by_user) {
                var route_node = getOneRouteNode(country: TenonP2pLib.sharedInstance.local_country)
                if (route_node.ip.isEmpty) {
                    route_node = getOneRouteNode(country: TenonP2pLib.sharedInstance.choosed_country)
                    if (route_node.ip.isEmpty) {
                        for country in defaultRoute {
                            route_node = getOneRouteNode(country: country)
                            if (!route_node.ip.isEmpty) {
                                break
                            }
                        }
                    }
                }

                var ex_route_node = initRouteNode()
                if (TenonP2pLib.sharedInstance.local_country == "CN" &&
                        (TenonP2pLib.sharedInstance.choosed_country == "SG" ||
                            TenonP2pLib.sharedInstance.choosed_country == "JP")) {
                    ex_route_node = getOneRouteNode(country: "US")
                    if (ex_route_node.ip.isEmpty) {
                        for country in defaultRoute {
                            ex_route_node = getOneRouteNode(country: country)
                            if (!ex_route_node.ip.isEmpty) {
                                break
                            }
                        }
                    }
                }
                
                
                var vpn_node = getOneVpnNode(country: TenonP2pLib.sharedInstance.choosed_country)
                if (vpn_node.ip.isEmpty) {
                    for country in defaultRoute {
                        vpn_node = getOneVpnNode(country: country)
                        if (!vpn_node.ip.isEmpty) {
                            break
                        }
                    }
                }

                
                let route_ip_int = LibP2P.changeStrIp(route_node.ip)
                let vpn_ip_int = LibP2P.changeStrIp(vpn_node.ip)
                var ex_route_ip_int: UInt32 = 0;
                var ex_route_port_int: Int32 = 0;
                if !ex_route_node.ip.isEmpty {
                    ex_route_ip_int = LibP2P.changeStrIp(ex_route_node.ip)
                    ex_route_port_int = Int32(ex_route_node.port) ?? 0
                }
                
                if (!route_node.ip.isEmpty) {
                    let mgr = ServerProfileManager.instance
                    if let profile = mgr.getActiveProfile() {
                        writeSSLocalConfFile((profile.toJsonConfig(
                            use_smart_route: Int32(TenonP2pLib.sharedInstance.use_smart_route),
                            route_ip: route_ip_int,
                            route_port: Int32(route_node.port)!,
                            vpn_ip: vpn_ip_int,
                            vpn_port: Int32(vpn_node.port)!,
                            ex_route_ip: ex_route_ip_int,
                            ex_route_port: ex_route_port_int,
                            seckey: vpn_node.passwd,
                            pubkey: TenonP2pLib.sharedInstance.GetPublicKey(),
                            status_fie: TenonP2pLib.sharedInstance.GetStatusFilepath(),
                            method: "aes-128-cfb")))
                    }
                }

                let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
                task.waitUntilExit()
                if task.terminationStatus != 0 {
                    print("start local server failed!")
                }

                sleep(3)
            }
        }
        NSLog("Start ss-local succeeded.")
    } else {
        NSLog("Start ss-local failed.")
    }
}

func StopSSLocal() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_ss_local.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        server_stoped_by_user = true
        NSLog("Stop ss-local succeeded.")
    } else {
        NSLog("Stop ss-local failed.")
    }
}

func InstallSSLocal() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR

    if !fileMgr.fileExists(atPath: appSupportDir + "ss-local-\(SS_LOCAL_VERSION)/tenon_local")
       || !fileMgr.fileExists(atPath: appSupportDir + "ss-local-\(SS_LOCAL_VERSION)/libmbedcrypto.0.dylib") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_ss_local.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install ss-local succeeded.")
        } else {
            NSLog("Install ss-local failed.")
        }
    }
}

func writeSSLocalConfFile(_ conf:[String:AnyObject]) -> Bool {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-config.json"
        var data: Data = try JSONSerialization.data(withJSONObject: conf, options: .prettyPrinted)

        // https://github.com/shadowsocks/ShadowsocksX-NG/issues/1104
        // This is NSJSONSerialization.dataWithJSONObject that likes to insert additional backslashes.
        // Escaped forward slashes is also valid json.
        // Workaround:
        let s = String(data:data, encoding: .utf8)!
        data = s.replacingOccurrences(of: "\\/", with: "/").data(using: .utf8)!
        
        let oldSum = getFileSHA1Sum(filepath)
        try data.write(to: URL(fileURLWithPath: filepath), options: .atomic)
        let newSum = data.sha1()
        
        if oldSum == newSum {
            NSLog("writeSSLocalConfFile - File has not been changed.")
            return false
        }
        
        return true
    } catch {
        NSLog("Write ss-local file failed.")
    }
    return false
}

func removeSSLocalConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-config.json"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
        
    }
}

func randomCustom(min: Int, max: Int) -> Int {
    let y = arc4random() % UInt32(max) + UInt32(min)
    return Int(y)
}

func getOneRouteNode(country: String) -> (ip: String, port: String) {
    let res_str = LibP2P.getVpnNodes(country, true) as String
    if (res_str.isEmpty) {
        return ("", "")
    }
    
    let node_arr: Array = res_str.components(separatedBy: ",")
    if (node_arr.count <= 0) {
        return ("", "")
    }
    
    let rand_pos = randomCustom(min: 0, max: node_arr.count)
    let node_info_arr = node_arr[rand_pos].components(separatedBy: ":")
    if (node_info_arr.count < 5) {
        return ("", "")
    }
    
    return (node_info_arr[0], node_info_arr[2])
}

func getOneVpnNode(country: String) -> (ip: String, port: String, passwd: String) {
    let res_str = LibP2P.getVpnNodes(country, false) as String
    if (res_str.isEmpty) {
        return ("", "", "")
    }
    
    let node_arr: Array = res_str.components(separatedBy: ",")
    if (node_arr.count <= 0) {
        return ("", "", "")
    }
    
    let rand_pos = randomCustom(min: 0, max: node_arr.count)
    let node_info_arr = node_arr[rand_pos].components(separatedBy: ":")
    if (node_info_arr.count < 5) {
        return ("", "", "")
    }
    
    return (node_info_arr[0], node_info_arr[1], node_info_arr[3])
}

func SyncSSLocal(choosed_country: String, local_country: String, smart_route: Int32) {
   
    var route_node = getOneRouteNode(country: local_country)
    if (route_node.ip.isEmpty) {
        route_node = getOneRouteNode(country: choosed_country)
        if (route_node.ip.isEmpty) {
            for country in defaultRoute {
                route_node = getOneRouteNode(country: country)
                if (!route_node.ip.isEmpty) {
                    break
                }
            }
        }
    }

    var ex_route_node = initRouteNode()
    if (TenonP2pLib.sharedInstance.local_country == "CN" &&
            (TenonP2pLib.sharedInstance.choosed_country == "SG" ||
                TenonP2pLib.sharedInstance.choosed_country == "JP")) {
        ex_route_node = getOneRouteNode(country: "US")
        if (ex_route_node.ip.isEmpty) {
            for country in defaultRoute {
                ex_route_node = getOneRouteNode(country: country)
                if (!ex_route_node.ip.isEmpty) {
                    break
                }
            }
        }
    }
    
    var vpn_node = getOneVpnNode(country: choosed_country)
    if (vpn_node.ip.isEmpty) {
        for country in defaultRoute {
            print("get vpn node from coutnry: \(country)")
            vpn_node = getOneVpnNode(country: country)
            if (!vpn_node.ip.isEmpty) {
                break
            }
        }
    }
    
    print("rotue: \(route_node.ip):\(route_node.port)")
    print("vpn: \(vpn_node.ip):\(vpn_node.port),\(vpn_node.passwd)")
    
    let route_ip_int = LibP2P.changeStrIp(route_node.ip)
    let vpn_ip_int = LibP2P.changeStrIp(vpn_node.ip)
    print("vpn_ip_int: \(vpn_ip_int)")
    var ex_route_ip_int: UInt32 = 0;
    var ex_route_port_int: Int32 = 0;
    if !ex_route_node.ip.isEmpty {
        ex_route_ip_int = LibP2P.changeStrIp(ex_route_node.ip)
        ex_route_port_int = Int32(ex_route_node.port) ?? 0
    }
    
    let pubkey = LibP2P.getPublicKey() as String;
    
    var changed: Bool = false
    changed = changed || generateSSLocalLauchAgentPlist()
    var mgr = ServerProfileManager.instance
    print("get mgr instance check is nil: \(mgr.activeProfileId != nil)")
    if mgr.activeProfileId != nil {
        if let profile = mgr.getActiveProfile() {
            changed = changed || writeSSLocalConfFile((profile.toJsonConfig(
                use_smart_route: smart_route,
                route_ip: route_ip_int,
                route_port: Int32(route_node.port)!,
                vpn_ip: vpn_ip_int,
                vpn_port: Int32(vpn_node.port)!,
                ex_route_ip: ex_route_ip_int,
                ex_route_port: ex_route_port_int,
                seckey: vpn_node.passwd,
                pubkey: pubkey,
                status_fie: TenonP2pLib.sharedInstance.GetStatusFilepath(),
                method: "aes-128-cfb")))
        }
        
        let on = UserDefaults.standard.bool(forKey: "ShadowsocksOn")
        if on {
            if changed {
                StopSSLocal()
                DispatchQueue.main.asyncAfter(
                    deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1),
                    execute: {
                        () in
                        StartSSLocal()
                })
            } else {
                StartSSLocal()
            }
        } else {
            StopSSLocal()
        }
    } else {
        removeSSLocalConfFile()
        StopSSLocal()
    }
    //SyncPac()
    //SyncPrivoxy()
}

// --------------------------------------------------------------------------------
//  MARK: simple-obfs

func InstallSimpleObfs() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir + APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "simple-obfs-\(SIMPLE_OBFS_VERSION)/obfs-local")
        || !fileMgr.fileExists(atPath: appSupportDir + "plugins/obfs-local") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_simple_obfs.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: "/bin/sh", arguments: [installerPath!])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install simple-obfs succeeded.")
        } else {
            NSLog("Install simple-obfs failed.")
        }
    }
}

// --------------------------------------------------------------------------------
//  MARK: kcptun

func InstallKcptun() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "kcptun_\(KCPTUN_CLIENT_VERSION)/client") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_kcptun", ofType: "sh")
        let task = Process.launchedProcess(launchPath: "/bin/sh", arguments: [installerPath!])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install kcptun succeeded.")
        } else {
            NSLog("Install kcptun failed.")
        }
    }
}

// --------------------------------------------------------------------------------
//  MARK: v2ray-plugin

func InstallV2rayPlugin() {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "v2ray-plugin_\(V2RAY_PLUGIN_VERSION)/v2ray-plugin") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_v2ray_plugin", ofType: "sh")
        let task = Process.launchedProcess(launchPath: "/bin/sh", arguments: [installerPath!])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install v2ray-plugin succeeded.")
        } else {
            NSLog("Install v2ray-plugin failed.")
        }
    }
}

// --------------------------------------------------------------------------------
//  MARK: privoxy

func generatePrivoxyLauchAgentPlist() -> Bool {
    let privoxyPath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/privoxy.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_PRIVOXY_NAME
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    
    let arguments = [privoxyPath, "--no-daemon", "privoxy.config"]
    
    // For a complete listing of the keys, see the launchd.plist manual page.
    let dict: NSMutableDictionary = [
        "Label": "com.qiuyuzhou.shadowsocksX-NG.http",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    if oldSha1Sum != Sha1Sum {
        return true
    } else {
        return false
    }
}

func StartPrivoxy() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "start_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start privoxy succeeded.")
    } else {
        NSLog("Start privoxy failed.")
    }
}

func StopPrivoxy() {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop privoxy succeeded.")
    } else {
        NSLog("Stop privoxy failed.")
    }
}

func InstallPrivoxy() {

    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "privoxy-\(PRIVOXY_VERSION)/privoxy") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_privoxy.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install privoxy succeeded.")
        } else {
            NSLog("Install privoxy failed.")
        }
    }
    
    let userConfigPath = homeDir + USER_CONFIG_DIR + "user_privoxy.config"
    if !fileMgr.fileExists(atPath: userConfigPath) {
        let srcPath = Bundle.main.path(forResource: "user-privoxy", ofType: "config")!
        try! fileMgr.copyItem(atPath: srcPath, toPath: userConfigPath)
    }
}

func writePrivoxyConfFile() -> Bool {
    do {
        let defaults = UserDefaults.standard
        let bundle = Bundle.main
        let templatePath = bundle.path(forResource: "privoxy.template.config", ofType: nil)
        
        // Read template file
        var template = try String(contentsOfFile: templatePath!, encoding: .utf8)
        
        template = template.replacingOccurrences(of: "{http}", with: defaults.string(forKey: "LocalHTTP.ListenAddress")! + ":" + String(defaults.integer(forKey: "LocalHTTP.ListenPort")))
        template = template.replacingOccurrences(of: "{socks5}", with: defaults.string(forKey: "LocalSocks5.ListenAddress")! + ":" + String(defaults.integer(forKey: "LocalSocks5.ListenPort")))
        
        // Append the user config file to the end
        let userConfigPath = NSHomeDirectory() + USER_CONFIG_DIR + "user_privoxy.config"
        let userConfig = try String(contentsOfFile: userConfigPath, encoding: .utf8)
        template.append(contentsOf: userConfig)
        
        // Write to file
        let data = template.data(using: .utf8)
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy.config"
        
        let oldSum = getFileSHA1Sum(filepath)
        try data?.write(to: URL(fileURLWithPath: filepath), options: .atomic)
        let newSum = getFileSHA1Sum(filepath)
        
        if oldSum == newSum {
            return false
        }
        
        return true
    } catch {
        NSLog("Write privoxy file failed.")
    }
    return false
}

func removePrivoxyConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy.config"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
        
    }
}

func SyncPrivoxy() {
    var changed: Bool = false
    changed = changed || generatePrivoxyLauchAgentPlist()
    let mgr = ServerProfileManager.instance
    if mgr.activeProfileId != nil {
        changed = changed || writePrivoxyConfFile()
        
        let on = UserDefaults.standard.bool(forKey: "LocalHTTPOn")
        if on {
            if changed {
                StopPrivoxy()
                DispatchQueue.main.asyncAfter(
                    deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1),
                    execute: {
                        () in
                        StartPrivoxy()
                })
            } else {
                StartPrivoxy()
            }
        } else {
            StopPrivoxy()
        }
    } else {
        removePrivoxyConfFile()
        StopPrivoxy()
    }
}
