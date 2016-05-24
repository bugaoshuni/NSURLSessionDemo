//
//  ViewController.swift
//  NSURLSessionDemo
//
//  Created by jichanghe on 16/5/11.
//  Copyright © 2016年 hjc. All rights reserved.
//

import UIKit

class ViewController: UIViewController, NSURLSessionDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        最简单的调用()
        文件下载()
        文件上传()
        Downloader()
        同步请求()
        并发的控制()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
  
    func 最简单的调用() {
        /*
             NSURLSession.sharedSession() 来获取 NSURLSession 的实例，
            然后调用 dataTaskWithURL 方法传入我们要访问的 url，最后在闭包中处理请求的返回结果。
            NSURLSession 默认是不启动的，我们必须手工调用 resume() 方法，才会开始请求。
        */

        if let url = NSURL(string: "https://httpbin.org/get") {
            
            NSURLSession.sharedSession().dataTaskWithURL(url){ data, response, error in
                
                print("1、接口返回：\(data)")
                
                }.resume()
            
        }
    }
    
    /*
        2、NSURLSession 本身不会进行请求，而是通过创建 task 进行网络请求，同一个 NSURLSession 可以创建多个 task，并且这些 task 之间的 cache 和 cookie 是共享的。NSURLSession 都能创建task 的类型：
        NSURLSessionDataTask: 第一个例子中创建的就是 DataTask,它主要用于读取服务端的简单数据，比如 JSON 数据。
        NSURLSessionDownloadTask: 主要是进行文件下载，它针对大文件的网络请求做了更多的处理，比如下载进度，断点续传等等。
        NSURLSessionUploadTask: 主要是用于 对服务端发送文件 。
    */
    func 文件下载() {
        let imageURL = NSURL(string: "https://httpbin.org/image/png")!
        
        // location:下载好的文件的存放位置。
        //downloadTaskWithURL 会将文件保存在一个临时目录中，location 参数指向这个临时目录的位置，如果我们要将下载好的文件进行持久保存的话，我们还需要将文件从这个临时目录中移动出来。
        NSURLSession.sharedSession().downloadTaskWithURL(imageURL) { location, response, error in
            //通过 location 参数 找到文件的位置，然后将文件的内容读取出来
            guard let url = location else { return }
            guard let imageData = NSData(contentsOfURL: url) else { return }
            guard let image = UIImage(data: imageData) else { return }
            
            dispatch_async(dispatch_get_main_queue()) {
                
                print("2、下载图片后，在视图上显示出来， image = \(image)")
                
            }

        }.resume()
    }
    
    func 文件上传() {
        let uploadURL = NSURL(string: "https://httpbin.org/image/png")!
        let request = NSURLRequest(URL: uploadURL)
        
        let fileURL = NSURL(fileURLWithPath: "pathToUpload")
        NSURLSession.sharedSession().uploadTaskWithRequest(request, fromFile: fileURL) { data, response, error in
             print("3、上传图片")
        }.resume()
    }
    
    
    /*
     4、4.1 前面的所有例子 都是用 NSURLSession.sharedSession() 这样的方式得到的 NSURLSession 的实例，
        这个实例是全局共享的，并且功能受限。比如：全局实例没有代理对象，我们就不能够检测诸如下载进度这类的事件、无法设置后台下载，等等。
        我们可以创建我们自己的 NSURLSession 实例。
        NSURLSession 定义了两个构造方法：
     
         init(configuration:)       系统默认创建一个新的OperationQueue处理Session的消息。
         init(configuration: delegate: delegateQueue:)    回调的delegate 会被强引用。 可以设定delegate在哪个OperationQueue回调，如果我们将其设置为[NSOperationQueue mainQueue]就能在主线程进行回调。
        当不再需要连接 调用Session的invalidateAndCancel直接关闭，或者调用finishTasksAndInvalidate等待当前Task结束后关闭。这时Delegate会收到URLSession:didBecomeInvalidWithError:这个事件。Delegate收到这个事件之后会被解引用。
     
        4.2 NSURLSessionConfiguration 提供了三个默认的初始化方法：

        defaultSessionConfiguration -  使用全局的缓存、cookie 等信息， 默认配置项。
        ephemeralSessionConfiguration -  不会对缓存或 cookie 以及认证信息进行存储，相当于一个私有的 Session。。浏览器 的 阅后即焚 功能。
        backgroundSessionConfiguration - 网络操作 在你的应用切换到后台的时候还能继续工作。
     
  
     5. 如果是一个BackgroundSession，在Task执行的时候，用户切到后台，Session会和ApplicationDelegate做交互。当程序切到后台后，在BackgroundSession中的Task还会继续下载。
     现在分三个场景分析下Session和Application的关系：
     
     当加入了多个Task，程序没有切换到后台：这种情况Task会按照NSURLSessionConfiguration的设置正常下载，不会和ApplicationDelegate有交互。
     
     当加入了多个Task，程序切到后台，所有Task都完成下载：
     　　在切到后台之后，Session的Delegate不会再收到，Task相关的消息，直到所有Task全都完成后，系统会调用ApplicationDelegate的application:handleEventsForBackgroundURLSession:completionHandler:回调，之后“汇报”下载工作，对于每一个后台下载的Task调用Session的Delegate中的URLSession:downloadTask:didFinishDownloadingToURL:（成功的话）和URLSession:task:didCompleteWithError:（成功或者失败都会调用）。
     
     　　之后调用Session的Delegate回调URLSessionDidFinishEventsForBackgroundURLSession:。
     注意：在ApplicationDelegate被唤醒后，会有个参数ComplietionHandler，这个参数是个Block，这个参数要在后面Session的Delegate中didFinish的时候调用一下，如下
     
     
     当加入了多个Task，程序切到后台，下载完成了几个Task，然后用户又切换到前台。（程序没有退出）
     　　切到后台之后，Session的Delegate仍然收不到消息。在下载完成几个Task之后再切换到前台，系统会先汇报已经下载完成的Task的情况，然后继续下载没有下载完成的Task，后面的过程同第一种情况。
     
     当加入了多个Task，程序切到后台，几个Task已经完成，但还有Task还没有下载完的时候关掉强制退出程序，然后再进入程序的时候。（程序退出了）
     　　最后这个情况比较有意思，由于程序已经退出了，后面没有下完Session就不在了后面的Task肯定是失败了。但是已经下载成功的那些Task，新启动的程序也没有听“汇报”的机会了。经过实验发现，这个时候之前在NSURLSessionConfiguration设置的NSString类型的ID起作用了，当ID相同的时候，一旦生成Session对象并设置Delegate，马上可以收到上一次关闭程序之前没有汇报工作的Task的结束情况（成功或者失败）。但是当ID不相同，这些情况就收不到了，因此为了不让自己的消息被别的应用程序收到，或者收到别的应用程序的消息，起见ID还是和程序的Bundle名称绑定上比较好，至少保证唯一性。

     */

    func 后台下载() {
        let imageURL = NSURL(string: "https://httpbin.org/image/png")!
        //传入的字符串 “download”，这个用作当前下载任务的标识，用于保证下载任务在后台的运行。
        let session = NSURLSession(configuration: NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("download"))
        session.downloadTaskWithURL(imageURL).resume()
    }
    
    // timeoutIntervalForRequest 和 timeoutIntervalForResource :网络操作的 超时时间。 前者每次有新data到达时重置;后者限制了整个资源请求时长 
    //allowsCellularAccess 属性可以控制是否允许使用无线网络。HTTPAdditionalHeaders 可以指定 HTTP 请求头。
    
    func 配置session() {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        //添加headers
        configuration.HTTPAdditionalHeaders = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        NSURLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    
    /*
     6、过去通过 NSURLConnection.sendSynchronousRequest()方法能同步请求数据。
     从iOS9起，苹果建议废除 NSURLConnection
     如果想要NSURLSession也能够同步请求，即数据获取后才继续执行下面的代码，使用信号、信号量就可以实现。
     */

    func 同步请求() {
        //创建NSURL对象
        let urlString:String = "http://www.baidu.com"
        let url:NSURL! = NSURL(string: urlString)
        
        //创建请求对象
        let request:NSURLRequest = NSURLRequest(URL:url)
        
        let session = NSURLSession.sharedSession()
        //dispatch_semaphore是GCD用来同步的一种方式
        let semaphore = dispatch_semaphore_create(0)    //创建一个semaphore,参数:信号的总量，必须 >=0，否则 返回NULL
        
        let dataTask = session.dataTaskWithRequest(request,
                                                   completionHandler: {(data,response,error) -> Void in
                                                    if error != nil{
                                                        print(error?.code)
                                                        print(error?.description)
                                                    }else{
                                                        let str = NSString(data: data!, encoding: NSUTF8StringEncoding)
                                                        print (str)
                                                    }
                                                    dispatch_semaphore_signal(semaphore)    //发送一个信号,让信号总量加1
        })as NSURLSessionTask
        
        //使用resume方法启动任务
        dataTask.resume()
        
        dispatch_semaphore_wait(semaphore,DISPATCH_TIME_FOREVER)    //等待信号，当信号总量 <=0 的时候就会一直等待，否则就可以正常的执行，并让 信号总量-1

        print("数据加载完毕")
        //继续执行其他代码。。。。。

    }
    
     func 并发的控制() {
        let group = dispatch_group_create()
        let semaphore = dispatch_semaphore_create(10)   //创建了一个初使值为10的semaphore
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        
        //每一次for循环都会创建一个新的线程，线程结束的时候会发送一个信号，线程创建之前会信号等待，所以当同时创建了10个线程之后，for循环就会阻塞，等待有线程结束之后会增加一个信号才继续执行，如此就形成了对并发的控制，
        //一个并发数为10的一个线程队列。
        for i in 0 ..< 100 {
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            
            dispatch_group_async(group, queue) { () -> Void in
                print("i= \(i)")
                sleep(2);
                dispatch_semaphore_signal(semaphore);
            }
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        
    }
}

/*
   7、前面 都是通过一个闭包 处理请求完成的数据。
    监听网络操作过程中发生的事件 就需要用到代理。比如 下载 大文件 的时候显示 下载进度。
 
    NSURLSession 的代理：
    1、NSURLSessionDelegate - 代理的基类，定义了网络请求最基础的代理方法。
    2、NSURLSessionTaskDelegate - 网络请求任务相关的代理方法。
    3、NSURLSessionDownloadDelegate - 下载任务相关的代理方法，比如下载进度等等。
    4、NSURLSessionDataDelegate - 用于普通数据任务和上传任务。
 */
class Downloader:NSObject, NSURLSessionDownloadDelegate {
    
    var session: NSURLSession?
    
    override init() {
        
        super.init()
        
        let imageURL = NSURL(string: "https://httpbin.org/image/png")!
        session = NSURLSession(configuration: NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("taask"), delegate: self, delegateQueue: nil)
        session?.downloadTaskWithURL(imageURL).resume()
        
    }
    
    //下载完成的通知
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        print("9.1、下载完成")
    }
    //下载进度变化的通知
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("9.2、正在下载 \(totalBytesWritten)/\(totalBytesExpectedToWrite)")
    }
    //下载进度恢复的通知
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
        print("9.3、从 \(fileOffset) 处恢复下载，一共 \(expectedTotalBytes)")
        
    }
}


/*
 优点：
 1、后台上传和下载：只需在创建NSURLSession的时候配置一个选项，就能得到后台网络的所有好处。这样可以延长电池寿命，并且还支持UIKit的多task，在进程间使用相同的委托模型。
 2、能够暂停和恢复网络操作：使用NSURLSession API能够暂停，停止，恢复所有的网络任务，再也完全不需要子类化NSOperation.
 3、可配置的容器：对于NSURLSession里面的requests来说，每个NSURLSession都是可配置的容器。举个例来说，假如你需要设置HTTP header选项，你只用做一次，session里面的每个request就会有同样的配置。
 4、提高认证处理：认证是在一个指定的连接基础上完成的。在使用NSURLConnection时，如果发出一个访问，会返回一个任意的request。此时，你就不能确切的知道哪个request收到了访问。而在NSURLSession中，就能用代理处理认证。
 5、丰富的代理模式：在处理认证的时候，NSURLConnection有一些基于异步的block方法，但是它的代理方法就不能处理认证，不管请求是成功或是失败。在NSURLSession中，可以混合使用代理和block方法处理认证。
 6、上传和下载通过文件系统:它鼓励将数据(文件内容)从元数据(URL和settings)中分离出来。
 */

