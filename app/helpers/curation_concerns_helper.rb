module CurationConcernsHelper
  include ::BlacklightHelper
  include CurationConcerns::MainAppHelpers

  # If it's an image, use our custom partial, otherwise
  # do what CC/Sufia did before.
  def show_page_representative_media(presenter)
    if presenter.representative_id.present? && presenter.representative_presenter.present? && presenter.representative_presenter.image?
      render 'show_page_image', member: presenter.representative_presenter, size: :large
    else
      render 'representative_media', presenter: presenter
    end
  end
end
