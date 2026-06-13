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
        contentView.layer.addSublayer(gradientLayer)
        contentView.addSubview(titleLabel)
        contentView.addSubview(albumBadge)

        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

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
        albumBadge.text      = " #\(photo.albumId) "
        currentURLString     = photo.thumbnailUrl
        thumbnailImageView.image = nil
        loadImage(from: photo.thumbnailUrl)
    }

    private func loadImage(from urlString: String) {
        if let cached = sharedImageCache.object(forKey: urlString as NSString) {
            thumbnailImageView.image = cached
            return
        }
        guard let url = URL(string: urlString) else { return }
        downloadTask?.cancel()
        downloadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let image = UIImage(data: data),
                  self.currentURLString == urlString else { return }
            sharedImageCache.setObject(image, forKey: urlString as NSString, cost: data.count)
            DispatchQueue.main.async {
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
        downloadTask            = nil
        thumbnailImageView.image = nil
        titleLabel.text         = nil
        albumBadge.text         = nil
        currentURLString        = nil
    }
}
