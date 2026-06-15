import UIKit

// MARK: - Shared Image Cache
let sharedImageCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 150
    cache.totalCostLimit = 1024 * 1024 * 100
    return cache
}()

// MARK: - Photo Cell
final class PhotoCell: UICollectionViewCell {

    static let reuseIdentifier = "PhotoCell"

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode   = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.systemGray5
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font          = .systemFont(ofSize: 11, weight: .medium)
        l.textColor     = .white
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let albumBadge: UILabel = {
        let l = UILabel()
        l.font                = .systemFont(ofSize: 10, weight: .bold)
        l.textColor           = .white
        l.textAlignment       = .center
        l.backgroundColor     = UIColor.systemBlue.withAlphaComponent(0.85)
        l.layer.cornerRadius  = 8
        l.layer.masksToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let gradientLayer: CAGradientLayer = {
        let gl = CAGradientLayer()
        gl.colors    = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.72).cgColor]
        gl.locations = [0.45, 1.0]
        return gl
    }()

    /// Shown only when the image download fails for any reason.
    private let placeholderImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: "photo", withConfiguration: config))
        iv.tintColor       = UIColor.systemGray3
        iv.contentMode     = .center
        iv.backgroundColor = UIColor.systemGray6
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true          // hidden by default; shown only on failure
        return iv
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private var currentURLString: String?
    private var downloadTask: URLSessionDataTask?

    override init(frame: CGRect) { super.init(frame: frame); setupUI() }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }

    private func setupUI() {
        contentView.layer.cornerRadius  = 10
        contentView.layer.masksToBounds = true
        contentView.backgroundColor     = UIColor.systemGray6
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(placeholderImageView)   // sits above thumbnail
        contentView.addSubview(activityIndicator)
        contentView.layer.addSublayer(gradientLayer)
        contentView.addSubview(titleLabel)
        contentView.addSubview(albumBadge)

        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Placeholder fills the cell exactly like the thumbnail
            placeholderImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            placeholderImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            placeholderImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            placeholderImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            albumBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            albumBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            albumBadge.heightAnchor.constraint(equalToConstant: 20),
            albumBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
    }

    func configure(with photo: PhotoDTO) {
        titleLabel.text      = photo.title.capitalized
        albumBadge.text      = " #\(photo.id) "
        currentURLString     = photo.thumbnailUrl
        thumbnailImageView.image = nil
        loadImage(from: photo.thumbnailUrl)
    }

    private func loadImage(from urlString: String) {
        if let cached = sharedImageCache.object(forKey: urlString as NSString) {
            thumbnailImageView.image = cached
            return
        }
        guard let url = URL(string: urlString) else {
            placeholderImageView.isHidden = false
            return
        }
        downloadTask?.cancel()
        
        activityIndicator.startAnimating()
        
        downloadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self, self.currentURLString == urlString else { return }

            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                // Show placeholder on any error, nil data, or bad image bytes
                guard error == nil, let data, let image = UIImage(data: data) else {
                    self.placeholderImageView.isHidden = false
                    return
                }
                self.placeholderImageView.isHidden = true
                sharedImageCache.setObject(image, forKey: urlString as NSString, cost: data.count)
                UIView.transition(with: self.thumbnailImageView, duration: 0.2,
                                  options: .transitionCrossDissolve) {
                    self.thumbnailImageView.image = image
                }
            }
        }
        downloadTask?.resume()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        downloadTask?.cancel()
        downloadTask             = nil
        thumbnailImageView.image = nil
        titleLabel.text          = nil
        albumBadge.text          = nil
        currentURLString         = nil
        placeholderImageView.isHidden = true   // reset for next cell
        activityIndicator.stopAnimating()
    }
}
