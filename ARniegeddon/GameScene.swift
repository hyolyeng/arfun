import ARKit

class GameScene: SKScene {
  var sceneView: ARSKView {
    return view as! ARSKView
  }

  var isWorldSetUp = false
  var sight: SKSpriteNode!
  var timer: Timer!
  var messageNode: SKLabelNode!
  var scoreNode: SKLabelNode!
  var levelupmessage: SKSpriteNode!
  var isGamePaused = true {
    didSet {
      if isGamePaused {
        if let timer = timer {
          timer.invalidate()
        }
      } else {
        levelupmessage.isHidden = true
        startTimer()
      }
    }
  }
  var howtoStep = -1 {
    didSet {
      displayHowToNextStep()
    }
  }
  var score = 0 {
    didSet {
      scoreNode.text = String(format: "LVL: %d SCORE: %d", level, score)

      if level == 1 && score == 100 {
        // level up!
        showLevelUpMessage()
        level += 1
      }
    }
  }
  var level = 1 {
    didSet {
      score = 0
    }
  }

  var numBullets = 6 {
    didSet {
      updateBullets()
    }
  }

  var bullets: [SKNode]!

  var hasBugspray = false {
    didSet {
      let sightImageName = hasBugspray ? "bugspraySight" : "sight"
      sight.texture = SKTexture(imageNamed: sightImageName)
    }
  }

  let gameSize = CGSize(width: 2, height: 2)

  @objc
  private func createTarget() {
    guard let currentFrame = sceneView.session.currentFrame else { return }

    startTimer()

    var type = NodeType.target
    if Int(arc4random_uniform(5)) == 0 {
      // create bear
      type = NodeType.bear
    }

    // Create a transform with a translation of 0.2 meters in front of the camera
    var translation = matrix_identity_float4x4
    translation.columns.3.x = Float.random(min: -1, max: 1)
    translation.columns.3.y = Float.random(min: -1, max: -0.5)
    translation.columns.3.z = Float.random(min: -10, max: -0.2)
    let transform = simd_mul(currentFrame.camera.transform, translation)
    let anchor = Anchor(transform: transform)
    anchor.type = type

    sceneView.session.add(anchor: anchor)

    let deadlineTime = DispatchTime.now() + .seconds(3)
    DispatchQueue.main.asyncAfter(deadline: deadlineTime) { [weak self, anchor] in
      self?.sceneView.session.remove(anchor: anchor)
    }
  }

  private func displayHowToNextStep() {
    for node in children {
      if node.name == "howto" {
        node.removeFromParent()
      }
    }
    if howtoStep > 0 && howtoStep <= 5 {
      let welcome = SKSpriteNode(imageNamed: String(format: "welcome%d", howtoStep))
      welcome.name = "howto"
      addChild(welcome)
    } else if howtoStep > 0 {
      howtoStep = -1
      isGamePaused = false
    }
  }

  private func initializeBullets() {
    bullets = []
    var i = 0
    while i < 6 {
      let bullet = SKSpriteNode(imageNamed: "bullet")
      bullet.position.x = frame.width / 2 - bullet.size.width - 5
      bullet.position.y = frame.height / 2 - (bullet.size.height * CGFloat(i + 1))
      bullets.append(bullet)
      addChild(bullet)
      i += 1
    }

    updateBullets()
  }

  private func getRandomTimeInterval() -> TimeInterval {
    if level == 1 {
      return Double(Float.random(min: 1, max: 3))
    } else if level == 2 {
      return Double(Float.random(min: 0.5, max: 2))
    }
    return Double(Float.random(min: 0, max: 1))
  }

  private func updateBullets() {
    var i = 0
    while i < numBullets {
      bullets[i].isHidden = false
      i += 1
    }
    while i < 6 {
      bullets[i].isHidden = true
      i += 1
    }
  }

  private func addWeaponAnchor() {
    guard let currentFrame = sceneView.session.currentFrame else { return }

    var translation = matrix_identity_float4x4
    translation.columns.3.x = Float.random(min: -1, max: 1)
    translation.columns.3.y = Float.random(min: -1, max: 1)
    translation.columns.3.z = Float.random(min: -3, max: -0.2)
    let transform = simd_mul(currentFrame.camera.transform, translation)
    let anchor = Anchor(transform: transform)
    anchor.type = NodeType.rifle
    sceneView.session.add(anchor: anchor)
  }

  private func addBangAnchor() -> Anchor? {
    guard let currentFrame = sceneView.session.currentFrame else { return nil }

    let location = sight.position
    var translation = matrix_identity_float4x4
    translation.columns.3.x = Float(location.x)
    translation.columns.3.y = Float(location.y)
    translation.columns.3.z = -0.6
    let transform = simd_mul(currentFrame.camera.transform, translation)
    let anchor = Anchor(transform: transform)
    anchor.type = NodeType.bang
    sceneView.session.add(anchor: anchor)
    return anchor
  }

  private func startTimer() {
    if let timer = timer {
      timer.invalidate()
    }
    timer = Timer.scheduledTimer(timeInterval: getRandomTimeInterval(), target: self, selector: #selector(GameScene.createTarget), userInfo: nil, repeats: false)
  }

  private func setUpWorld() {
    guard let _ = sceneView.session.currentFrame
      else { return }

    initializeBullets()
    addWeaponAnchor()
    initializeLevelUpMessage()
    howtoStep = 1

    isWorldSetUp = true
  }

  private func initializeLevelUpMessage() {
    levelupmessage = SKSpriteNode(imageNamed: "levelupmessage")
    levelupmessage.isHidden = true
    addChild(levelupmessage)
  }

  override func update(_ currentTime: TimeInterval) {
    if !isWorldSetUp {
      setUpWorld()
    }

    guard let currentFrame = sceneView.session.currentFrame,
      let lightEstimate = currentFrame.lightEstimate else {
        return
    }

    let neutralIntensity: CGFloat = 1000
    let ambientIntensity = min(lightEstimate.ambientIntensity,
                               neutralIntensity)
    let blendFactor = 1 - ambientIntensity / neutralIntensity

    for node in children {
      if let bug = node as? SKSpriteNode {
        bug.color = .black
        bug.colorBlendFactor = blendFactor
      }
    }

    for anchor in currentFrame.anchors {
      guard let node = sceneView.node(for: anchor),
        node.name == NodeType.rifle.rawValue
        else { continue }

      let distance = simd_distance(anchor.transform.columns.3, currentFrame.camera.transform.columns.3)
      if distance < 0.1 {
        remove(rifle: anchor)
        numBullets = 6
        // add another weapon as soon as this one is picked up
        addWeaponAnchor()
        break
      }
    }
  }

  private func remove(rifle anchor: ARAnchor) {
    print("removed weapon")
    sceneView.session.remove(anchor: anchor)
  }

  override func didMove(to view: SKView) {
    sight = SKSpriteNode(imageNamed: "sight")
    addChild(sight)

    scoreNode = SKLabelNode(text: String(format: "LVL: %d SCORE: %d", level, score))
    scoreNode.position.x = -frame.width / 2 + scoreNode.frame.size.width / 2
    scoreNode.position.y = frame.height / 2 - scoreNode.frame.size.height - 5
    scoreNode.fontName = "Chalkduster"
    scoreNode.fontSize = 20
    scoreNode.fontColor = UIColor(red: 0.125, green: 0.76, blue: 0.055, alpha: 1)
    addChild(scoreNode)

    messageNode = SKLabelNode(text: "")
    messageNode.fontColor = UIColor.red
    messageNode.fontName = "Chalkduster"
    messageNode.fontSize = 36
    messageNode.preferredMaxLayoutWidth = frame.width - 30
    addChild(messageNode)

    srand48(Int(Date.timeIntervalSinceReferenceDate))
  }

  private func showLevelUpMessage() {
    isGamePaused = true

    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] (_) in
      self?.run(Sounds.win)
      self?.levelupmessage.isHidden = false
    }
  }

  private func showMessage(_ text: String) {
    messageNode.text = text
    messageNode.numberOfLines = 0
    Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] (_) in
      self?.messageNode.text = ""
    }
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    if howtoStep > 0 {
      howtoStep += 1
      return
    }
    if isGamePaused {
      isGamePaused = false
      return
    }
    guard let currentFrame = sceneView.session.currentFrame else { return }

    if numBullets < 1 {
      run(Sounds.gunclick)
      showMessage("Out of ammo! Pick up a weapon!")
      // if there's no weapons on the scene, add one.
      for anchor in currentFrame.anchors {
        if let node = sceneView.node(for: anchor),
          node.name == NodeType.rifle.rawValue {
          return
        }
        addWeaponAnchor()
      }
      return
    }

    numBullets -= 1
    let location = sight.position
    let hitNodes = nodes(at: location)

    var hitTarget: SKNode?
    for node in hitNodes {
      if node.name == NodeType.target.rawValue || node.name == NodeType.bear.rawValue {
        hitTarget = node
        break
      }
    }

    if hitTarget == nil {
      run(Sounds.bang)
    }

    if let hitTarget = hitTarget,
      let anchor = sceneView.anchor(for: hitTarget) {

      var hitNodeType: NodeType?
      if hitTarget.name == NodeType.target.rawValue {
        hitNodeType = NodeType.target
      } else if hitTarget.name == NodeType.bear.rawValue {
        hitNodeType = NodeType.bear
      }

      var bangAnchor: Anchor?
      let bangAction = SKAction.run {
        bangAnchor = self.addBangAnchor()
      }
      let firstActionGroup = SKAction.group([Sounds.bang, bangAction, hitNodeType == NodeType.bear ? Sounds.beargrowl : Sounds.hit])

      let removeHitTargetAction = SKAction.run {
        self.sceneView.session.remove(anchor: anchor)
        if let bangAnchor = bangAnchor {
          self.sceneView.session.remove(anchor: bangAnchor)
        }
      }

      let sequence = [SKAction.wait(forDuration: 0.3), firstActionGroup, SKAction.wait(forDuration: 0.2), removeHitTargetAction]
      hitTarget.run(SKAction.sequence(sequence))

      if hitNodeType == NodeType.target {
        score += 100
      } else if hitNodeType == NodeType.bear {
        score -= 200
      }
    }

    hasBugspray = false
  }
}
