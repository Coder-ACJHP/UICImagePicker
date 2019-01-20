//
//  PhotoCell.swift
//  CoderImagePicker
//
//  Created by Onur Işık on 19.01.2019.
//  Copyright © 2019 Onur Işık. All rights reserved.
//

import UIKit

class PhotoCell: UICollectionViewCell {

    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var shadowView: UIView!
    @IBOutlet weak var checkedIconView: UIImageView!
    
    let checkedIcon: UIImage = UIImage(named: "selectedIcon")!
    
    override var isSelected: Bool {
        didSet {
            
            if isSelected {
                
                UIView.transition(with: self, duration: 0.2, options: .transitionCrossDissolve, animations: {
                    self.shadowView.isHidden = false
                    self.checkedIconView.image = self.checkedIcon
                }, completion: nil)
                
            } else {
                
                UIView.transition(with: self, duration: 0.2, options: .transitionCrossDissolve, animations: {
                    self.shadowView.isHidden = true
                    self.checkedIconView.image = nil
                }, completion: nil)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

}
