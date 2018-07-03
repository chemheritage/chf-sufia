module CHF
  class GenericWorkIndexer < CurationConcerns::WorkIndexer

    def generate_solr_document

      super.tap do |doc|
        %w(additional_credit inscription date_of_work).each do |field|
          entries = remove_duplicates(field)
          doc[ActiveFedora.index_field_mapper.solr_name(field, :stored_searchable)] = entries.map { |entry| entry.display_label }
        end
        unless object.physical_container.nil?
          require_dependency Rails.root.join('lib','chf','utils','parse_fields')

          # formatted
          doc[ActiveFedora.index_field_mapper.solr_name("physical_container", :stored_searchable)] = CHF::Utils::ParseFields.display_physical_container(object.physical_container)

          # and original
          doc["physical_container_structured_ss"] = object.physical_container
        end

        makers = %w(after artist author addressee creator_of_work contributor engraver interviewee interviewer manner_of manufacturer photographer printer printer_of_plates publisher)
        maker_facet = makers.map { |field| object.send(field).to_a }.flatten.uniq
        doc[ActiveFedora.index_field_mapper.solr_name('maker_facet', :facetable)] = maker_facet

        places = %W{place_of_interview place_of_manufacture place_of_publication place_of_creation}
        place_facet = places.map { |field| object.send(field).to_a }.flatten.uniq
        doc[ActiveFedora.index_field_mapper.solr_name('place_facet', :facetable)] = place_facet

        date_values = DateValues.new(object)

        # used for facetting and histogram facet display
        doc[ActiveFedora.index_field_mapper.solr_name('year_facet', type: :integer)] = date_values.expanded_years
        # used for sorting, need just one date for a sort.
        doc["earliest_year"] = date_values.min_year
        doc["latest_year"] = date_values.max_year

        # rights as label, not just URI identifier
        license_service = CurationConcerns::LicenseService.new
        doc[ActiveFedora.index_field_mapper.solr_name('rights_label', :searchable)] = object.rights.collect do |id|
          # If the thing isn't found in the license service, just ignore it.
          license_service.authority.find(id).fetch('term', nil)
        end.compact

        # Index representative image to use as thumb on search results etc
        representative = ultimate_representative(object)
        if representative
          # need to index these for when it's a child work on a parent's show page
          # Note corresponding code in GenericWork#update_index makes sure works using
          # this work as a representative also get updated.
          doc[ActiveFedora.index_field_mapper.solr_name('representative_width', type: :integer)] = representative.width.first if representative.width.present?
          doc[ActiveFedora.index_field_mapper.solr_name('representative_height', type: :integer)] = representative.height.first if representative.height.present?
          doc[ActiveFedora.index_field_mapper.solr_name('representative_original_file_id')] = representative.original_file.id if representative.original_file
          doc[ActiveFedora.index_field_mapper.solr_name('representative_file_set_id')] = representative.id if representative.original_file
          doc[ActiveFedora.index_field_mapper.solr_name('representative_checksum')] = representative.original_file.checksum.value if representative.original_file

          # Our app tries not to use this field at all anymore, but just in case
          # set it to proper thumb URL as expected by stack, which is actually
          # fixed based on fileset id, although the thumb might not actually exist,
          # if it does this is it's URL.
          if representative.original_file
            if klass = ImageServiceHelper.image_url_service_class(CHF::Env.lookup('image_server_for_thumbnails'))
              doc['thumbnail_path_ss'] = klass.new(file_set_id: representative.id,
                                          file_id: representative.original_file.id,
                                          checksum: representative.original_file.checksum.value).thumb_url(size: :standard)
            else
              # ought to be using rails routing, but it's all just too much.
              doc['thumbnail_path_ss'] = "/downloads/#{representative.id}?file=thumbnail"
            end
          end

        end


        # Taken from hyrax, so we can facet on visibility settings
        # https://github.com/samvera/hyrax/blob/0d2e40e2ed09b07645dd71892e65c93aa58c88f9/app/indexers/hyrax/work_indexer.rb#L18
        doc['visibility_ssi'] = object.visibility

        # index structured date of works, so we can get them at index time
        # Not totally sure why we're getting duplicates here, the duplicates don't seem to make it to fedora,
        # but we have dups as input here when indexing after an edit. We just de-dup here for now to avoid
        # dups in index.
        doc['date_of_work_json_ssm'] = remove_duplicates('date_of_work').collect { |d| d.to_json(except: "id") }

        # Need all content-types for oai_dc serialization. This does force loading all members, was
        # that happening already, will it be a performance problem?
        doc['content_types_ssim'] = object.members.collect do |member|
          # We're NOT descending into child generic works, too crazy performance-wise.
          member.mime_type if member.respond_to?(:mime_type)
        end.uniq
      end
    end

    private

      def remove_duplicates(field)
        entries = object.send(field).to_a
        entries.uniq! {|e| e.id} # can return nil
        entries
      end

      # If works representative is another work, find IT's representative,
      # recursively, until you get a terminal node, presumably fileset.
      # Return nil if there is no terminal representative.
      def ultimate_representative(work)
        return nil if work.representative_id.nil?

        # Can't just use work.representative, does not work on empty index
        # But this does.
        candidate = begin
          ActiveFedora::Base.find(work.representative_id)
        rescue ActiveFedora::ObjectNotFoundError
          nil
        end

        return nil if candidate.nil?

        if candidate.respond_to?(:representative_id) && candidate.representative_id != candidate.id
          ultimate_representative(candidate)
        else
          candidate
        end
      end
  end
end
