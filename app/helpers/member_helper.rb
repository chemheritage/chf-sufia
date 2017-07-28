# helpers for rendering things related to display of 'members' or children
# of works, on a work page. A member can be a file set or a child work.
module MemberHelper

  def dropdown_menuitem(content, attributes = {})
    content_tag("li", content, {tabindex: "-1", role: "menuitem"}.merge(attributes))
  end

  # returns a <ul> with <li>s suitable to be used inside a bootstrap
  # dropdown-toggle, representing download options for the member passed in.
  # also includes a rights statement from parent.
  #
  # first arg member is normally required, but can be passed as nil for
  # creating a blank template for JS filling, as in viewer.
  #
  # used in show_page_image and image_viewer.
  #
  # Originally was a partial instead of a helper, and probably more readable
  # that way, but performance impact of partial was too much, on work pages
  # that wanted to display many members and call these many times. Not entirely
  # sure why partial so much slower than helper, even in production config.
  def member_download_menu(member, parent:, labelled_by: nil)
    list_elements = []

    if parent.has_rights_statement?
      list_elements << dropdown_menuitem(
          link_to(parent.rights_url,
                    target: "_blank",
                    class: 'rights-statement-inline') do
            safe_join([image_tag(parent.rights_icon, class: "rights-statement-logo"),
                       " ",
                       content_tag("span", parent.rights_icon_label, class: "rights-statement-label")])
          end
      )
      list_elements << "<li class='divider'></li>".html_safe
    end

    list_elements << '<li class="dropdown-header">Download this image</li>'.html_safe

    list_elements << dropdown_menuitem(
                      link_to("Original Image", ( member ? main_app.download_path(member.representative_id) : "#" ),
                        target: "_new",
                        id: "file_download",
                        data: {
                          content_hook: "dl-original-link",
                          analytics_category: "Work",
                          analytics_action: "download-tiff",
                          analytics_label: parent.id
                        })
                      )

    if CHF::Env.lookup(:use_image_server_downloads)
      list_elements << dropdown_menuitem(
                        link_to("Full-size JPEG",
                          (member ? iiif_image_url(member.riiif_file_id, format: "jpg", size: "full") : "#"),
                          target: "_new",
                          data: {
                            content_hook: "dl-jpeg-link",
                            analytics_category: "Work",
                            analytics_action: "download-jpg",
                            analytics_label: parent.id
                          })
                        )
    end

    content_tag("ul",
                safe_join(list_elements),
                class: "dropdown-menu",
                role: "menu",
                :'aria-labelledby' => labelled_by)
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
                 data: {confirm: "Deleting #{file_set} from #{application_name} is permanent. Click OK to delete this from #{application_name}, or Cancel to cancel this operation"}
      )
    end

    content_tag("ul",
                safe_join(list_items),
                class: "dropdown-menu dropdown-menu-right",
                role: "menu",
                :'aria-labelledby' => labelled_by)
  end
end
