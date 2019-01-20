//
//  ViewController.swift
//  CoderImagePicker
//
//  Created by Onur Işık on 19.01.2019.
//  Copyright © 2019 Onur Işık. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var pickImageButton: UIButton!
    @IBOutlet weak var testImageView: UIImageView!
    
    enum CardState {
        
        case expanded
        case collapsed
    }
    
    var cardViewController: CardViewController!
    var visualEffectView: UIVisualEffectView!
    
    let cardHeight: CGFloat = 650
    let cardHandleArea: CGFloat = 40
    
    var cardIsVisible: Bool = false
    var nextState: CardState {
        return cardIsVisible ? .collapsed : .expanded
    }
    
    var runningAnimations = [UIViewPropertyAnimator]()
    var animationProgressWhenInterrupted: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCard()
        
        self.pickImageButton.addTarget(self, action: #selector(handlePress(_:)), for: .touchUpInside)
    }

    fileprivate func setupCard() {
        
        visualEffectView = UIVisualEffectView()
        visualEffectView.frame = self.view.frame
        self.view.addSubview(visualEffectView)
        visualEffectView.isHidden = true
        
        cardViewController = CardViewController(nibName: "CardViewController", bundle: nil)
        self.addChild(cardViewController)
        self.view.addSubview(cardViewController.view)
        
        cardViewController.view.frame = CGRect(x: 0, y: self.view.frame.height, width: self.view.bounds.width, height: cardHeight)
        cardViewController.view.clipsToBounds = true
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handleCardPan(gestureRecognizer:)))
        cardViewController.handleArea.addGestureRecognizer(panGestureRecognizer)
        cardViewController.delegate = self
    }
    
    @objc fileprivate func handlePress(_ sender: UIButton) {
        self.animateTransitionIfNeeded(state: nextState, duration: 0.9)
    }
    
    @objc fileprivate func handleCardPan(gestureRecognizer: UIPanGestureRecognizer) {
        
        switch gestureRecognizer.state {
        case .began:
            startInteractiveTransition(state: nextState, duration: 0.9)
        case .changed:
            let transition = gestureRecognizer.translation(in: self.cardViewController.handleArea)
            var fractionComplete = transition.y / cardHeight
            fractionComplete = cardIsVisible ? fractionComplete : -fractionComplete
            updateInteractiveTransition(fractionCompleted: fractionComplete)
        case .ended:
            continueInteractiveTransition()
        default: break;
        }
    }
    
    fileprivate func animateTransitionIfNeeded(state: CardState, duration: TimeInterval) {
        
        if runningAnimations.isEmpty {
            
            let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0) {
                
                switch state {
                case .expanded:
                    self.visualEffectView.isHidden = false
                    self.cardViewController.view.frame.origin.y = self.view.frame.height - self.cardHeight
                case .collapsed:
                    self.cardViewController.view.frame.origin.y = self.view.frame.height
                }
            }
            
            frameAnimator.addCompletion { (_) in
                self.cardIsVisible = !self.cardIsVisible
                self.runningAnimations.removeAll()
            }
            
            frameAnimator.startAnimation()
            runningAnimations.append(frameAnimator)
            
            
            let cornerRadiusAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear) {
                
                switch state {
                case .expanded:
                    self.cardViewController.view.layer.cornerRadius = 10
                case .collapsed:
                    self.cardViewController.view.layer.cornerRadius = 0
                }
            }
            
            cornerRadiusAnimator.startAnimation()
            runningAnimations.append(cornerRadiusAnimator)
            
            let blurAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0) {
                switch state {
                case .expanded:
                    self.visualEffectView.effect = UIBlurEffect(style: .dark)
                case .collapsed:
                    self.visualEffectView.effect = nil
                }
            }
            
            blurAnimator.startAnimation()
            runningAnimations.append(blurAnimator)
            
            blurAnimator.addCompletion { (_) in
                if state == .collapsed {
                    self.visualEffectView.isHidden = true
                }
            }
        }
    }
    
    fileprivate func startInteractiveTransition(state: CardState, duration: TimeInterval) {
        
        if runningAnimations.isEmpty {
            animateTransitionIfNeeded(state: state, duration: duration)
        }
        
        for animator in runningAnimations {
            animator.pauseAnimation()
            animationProgressWhenInterrupted = animator.fractionComplete
        }
    }
    
    fileprivate func updateInteractiveTransition(fractionCompleted: CGFloat) {
        
        for animator in runningAnimations {
            animator.fractionComplete = fractionCompleted + animationProgressWhenInterrupted
        }
    }
    
    fileprivate func continueInteractiveTransition() {
        
        for animator in runningAnimations {
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
        }
        
    }
}

extension ViewController: CImagePickerControllerDelegate {
    func didFinishPickingImage(_ image: UIImage) {
        testImageView.image = image
        self.handlePress(UIButton())
    }
    
    func didCancelPickingImage() {
        debugPrint("Image picking cancelled!")
        self.handlePress(UIButton())
    }
}
