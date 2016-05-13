//
//  ViewController.swift
//  AVPlayerTest
//
//  Created by Kuu Miyazaki on 4/14/16.
//  Copyright © 2016 Ooyala. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {
    
    var player:AVPlayer! = nil
    var playing = false
    var firstPlay = true
    var videoURL:NSURL! = nil
    var playerLayer:AVPlayerLayer! = nil
    var sequenceNum = 0
    var duration:Float64 = 0
    var playbackTime:Double = 0
    var sessionId = ""
    var sessionStartTime = "" // YYYY-MM-DDThh:mm:ssZ
    var timer:NSTimer! = nil
    
    func getCurrentTimeDate() -> String {
        let formatter = NSDateFormatter()
        formatter.timeZone = NSTimeZone(name: "UTC")
        formatter.dateFormat = "yyyy-MM-dd hh:mm:ssZ"
        var dateStr = formatter.stringFromDate(NSDate())
        dateStr = dateStr.stringByReplacingOccurrencesOfString(" ", withString: "T")
        return dateStr.stringByReplacingOccurrencesOfString("+0000", withString: ".000Z")

    }
    
    func updatePlaybackTime() {
        playbackTime++
        sendPlayerEvent("playheadUpdate")
    }
    
    func startTimer() {
        stopTimer()
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(updatePlaybackTime), userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        guard let t:NSTimer = timer else {
            return
        }
        t.invalidate()
        timer = nil
    }
    
    func sendPlayerEvent(event: String){
        
        var eventItem:Dictionary<String, AnyObject> = [
            "sequenceNum": sequenceNum++,
            "time": getCurrentTimeDate(),
            "eventName": event
        ]
        
        switch event {
        case "display":
            break;
        case "playRequested":
            eventItem["isAutoPlay"] = false
            break;
        case "videoStarted":
            startTimer()
            break;
        case "playheadUpdate":
            eventItem["playheadPositionMillis"] = playbackTime * 1000
            break;
        case "pause":
            stopTimer()
            break;
        case "resume":
            startTimer()
            break;
        case "playthroughPercent":
            eventItem["percent"] = floor(playbackTime * 100 / duration)
            stopTimer()
            break;
        default:
            print("Unknown player event: " + event)
        }
        
        let params = [
            "pcode": "{provider code}",
            "clientTime": getCurrentTimeDate(),
            "sessionStartTime": sessionStartTime,
            "sessionId": sessionId,
            "asset": ["id": "{embed_code}", "idType": "ooyala"],
            "events": [
                eventItem
            ]
        ]
        sendRequest(params)
    }
    
    func sendRequest(params: NSDictionary){
        let url: NSURL = NSURL(string: "https://l.ooyala.com/v3/analytics/events")!
        let request:NSMutableURLRequest = NSMutableURLRequest(URL:url)
        request.HTTPMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(params, options: [])
        } catch {
            print(error)
        }
        print(params)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
            (data: NSData?, response: NSURLResponse?, error: NSError?) in
            print(response)
        }
        task.resume()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        videoURL = NSURL(string: "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")
        
        guard let session:AVAudioSession = AVAudioSession.sharedInstance() else {
            return
        }
        do {
            try session.setCategory(AVAudioSessionCategoryPlayback, withOptions: [])
            try session.setActive(true)
        } catch {
            print("Unable to set AudioSessionCategory")
        }
        

        player = AVPlayer(URL: videoURL!)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)
        
        sessionStartTime = getCurrentTimeDate()
        sessionId = NSUUID().UUIDString
        sendPlayerEvent("display")
    }

    override func viewWillDisappear(animation: Bool) {
        super.viewWillDisappear(animation)
        sendPlayerEvent("playthroughPercent")
        NSNotificationCenter.defaultCenter().removeObserver(self)

    }
    
    // If orientation changes
    override func willAnimateRotationToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        playerLayer.frame = self.view.frame
    }
    
    func playerDidReachEnd(){
        playerLayer.player!.seekToTime(kCMTimeZero)
        playerLayer.player!.play()
        
    }

    @IBAction func onTap(sender: AnyObject) {
        if (firstPlay) {
            let asset = AVURLAsset(URL: self.videoURL!, options: nil)
            let audioDuration = asset.duration
            duration = CMTimeGetSeconds(audioDuration)
            
            player.play()
            playing = true
            sendPlayerEvent("playRequested")
            sendPlayerEvent("videoStarted")
            firstPlay = false
        } else if (self.playing) {
            player.pause()
            playing = false
            sendPlayerEvent("pause")
        } else {
            player.play()
            playing = true
            sendPlayerEvent("resume")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

