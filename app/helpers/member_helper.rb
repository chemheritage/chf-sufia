# helpers for rendering things related to display of 'members' or children
# of works, on a work page. A member can be a file set or a child work.
module MemberHelper

  def dropdown_menuitem(content, attributes = {})
    content_tag("li", content, {tabindex: "-1", role: "menuitem"}.merge(attributes))
  end


  # returns array of <li> strings, INCLUDING the <li> header but NOT a <li> separator.
  def whole_work_download_options(work)
    list_elements = []
    list_elements << content_tag("li", "Download all #{work.public_member_presenters.count} images", class: "dropdown-header")

    pdf_link = link_to("PDF", "",
      data: {
        'download-deriv-type': "pdf",
        'download-whole-work-deriv': work.id,
        'analytics-category': "Work",
        'analytics-action':  "download_pdf",
        'analytics-label': work.id
      }
    )

    list_elements << dropdown_menuitem( pdf_link )

    zip_link = link_to("ZIP ".html_safe + content_tag("small", "of full-sized JPGs"), "",
      data: {
          'download-deriv-type': "zip",
          'download-whole-work-deriv': work.id,
          'analytics-category': "Work",
          'analytics-action':  "download_zip",
          'analytics-label': work.id
        }
      )

    list_elements << dropdown_menuitem( zip_link )

    return list_elements
  end

  # returns a <ul> with <li>s suitable to be used inside a bootstrap
  # dropdown-toggle, representing download options for the member passed in.
  # also includes a rights statement from parent.
  #
  #  filename_base, if provided, is used to make more human-readable
  # 'save as' download file names.
  #
  # used in show_page_image. image_viewer now does it's own JS version.
  #
  # Originally was a partial instead of a helper, and probably more readable
  # that way, but performance impact of partial was too much, on work pages
  # that wanted to display many members and call these many times. Not entirely
  # sure why partial so much slower than helper, even in production config.
  def member_download_menu(member, parent:, labelled_by: nil, filename_base: nil, whole_work_downloads: true)
    list_elements = []

    if parent.has_rights_statement?
      list_elements << content_tag("li", "Rights", class: "dropdown-header")

      list_elements << dropdown_menuitem(render_rights_statement(parent))
      list_elements << "<li class='divider'></li>".html_safe
    end

    if whole_work_downloads && parent && parent.public_member_presenters.size > 1
      list_elements.concat whole_work_download_options(parent)
      list_elements << "<li class='divider'></li>".html_safe
    end

    if member && (download_options = download_options(member, filename_base: filename_base)).count > 0
      list_elements << content_tag("li", "Download selected image", class: "dropdown-header")

      download_options.each do |option_config|
        list_elements << dropdown_menuitem(
          link_to(option_config[:url],
            data: {
              content_hook: "dl-original-link",
              analytics_category: "Work",
              analytics_action: option_config[:analyticsAction],
              analytics_label: parent.id
            }) do
            safe_join([
              option_config[:label],
              content_tag("small", " #{option_config[:subhead]}")
            ])
          end,
          target: "_new",
        )
      end
    end

    content_tag("ul",
                safe_join(list_elements),
                class: "dropdown-menu download-menu",
                role: "menu",
                :'aria-labelledby' => labelled_by)
  end

  def render_rights_statement(presenter)
    return nil unless presenter

    # content_tag is quicker than link_to for static url
    content_tag("a",
              href: presenter.rights_url,
              target: "_blank",
              class: 'rights-statement-inline') do
        image_tag(presenter.rights_icon || "", class: "rights-statement-logo") +
         " ".html_safe +
         content_tag("span", presenter.rights_icon_label, class: "rights-statement-label")
      end
  end

  # Used for controls (edit etc) on a 'file_set', normally only showed
  # to staff users.  Used in show_page_image.
  #
  # returns a <ul> with <li>s suitable to be used inside a bootstrap
  # dropdown-toggle.
  #
  # Originally was a partial instead of a helper, and probably more readable
  # that way, but performance impact of partial was too much, on work pages
  # that wanted to display many members and call these many times. Not entirely
  # sure why partial so much slower than helper, even in production config.
  def file_set_actions_menu(file_set, parent:, labelled_by: nil)
    list_items = []

    list_items << dropdown_menuitem(
      link_to 'File Detail', contextual_path(file_set, parent),
               title: file_set.to_s.inspect, target: "_blank"
    )

    list_items  << '<li class="divider"></li>'.html_safe

    if can?(:edit, file_set.id)
      list_items << dropdown_menuitem(
        link_to 'Edit', edit_polymorphic_path([main_app, file_set]),
                { title: "Edit #{file_set}" }
      )

      list_items << dropdown_menuitem(
        link_to 'Versions',  edit_polymorphic_path([main_app, file_set], anchor: 'versioning_display'),
                { title: "Display previous versions" }
      )
    end

    if can?(:destroy, file_set.id)
      list_items << dropdown_menuitem(
        link_to 'Delete', polymorphic_path([main_app, file_set]),
                 method: :delete, title: "Delete #{file_set}",
                 data: {confirm: "Deleting #{file_set} is permanent. Click OK to delete this, or Cancel to cancel this operation"}
      )
    end

    content_tag("ul",
                safe_join(list_items),
                class: "dropdown-menu dropdown-menu-right",
                role: "menu",
                :'aria-labelledby' => labelled_by)
  end


  # Calculate height matching width for a aspect ratio of member_presenter.
  # default target_width should match CSS, in chf_image_viewer.scss, .viewer-thumb-img `width`
  def member_proportional_height(member_presenter, target_width: ImageServiceHelper::THUMB_BASE_WIDTHS[:mini])
    original_width = member_presenter.representative_width.try(:to_i)
    original_height = member_presenter.representative_height.try(:to_i)

    if original_width && original_width > 0 && original_height && original_height > 0
      # make sure it's at least target_width / 4, stretch if needed.
      [(target_width.to_d * original_height / original_width).round(2), (target_width.to_d / 4).round(2)].max
    end
  end

  def can_promote_to_child_work?(pres)
    return false unless pres.respond_to? 'parent'
    [
      (can?(:edit, pres.id)),
      (pres.solr_document._source['has_model_ssim']  == ["FileSet"]),
      (can?(:edit, pres.parent.id)),
      (pres.parent.solr_document._source['has_model_ssim'] == ["GenericWork"]),
      (pres.parent.solr_document._source['member_ids_ssim'].include? pres.id),
    ].all?
  end

  def can_demote_to_file_set?(pres)
    [
      (can?(:delete, pres.id)),
      (pres.solr_document._source['has_model_ssim'] == ["GenericWork"] ),
      (pres.solr_document._source['member_ids_ssim'].uniq.count == 1),
      (pres.parent_work_presenters.present?),
      (pres.parent_work_presenters.count == 1 ),
      (pres.parent_work_presenters.first != nil ),
      (can?(:edit, pres.parent_work_presenters.first.solr_document._source['id'])),
      (pres.parent_work_presenters.first.solr_document._source['has_model_ssim'] == ["GenericWork"] ),
      (pres.parent_work_presenters.first.solr_document._source['member_ids_ssim'].include? pres.id ),
    ].all?
  end



end
