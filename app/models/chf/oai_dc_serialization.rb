module CHF

  #
  #    CHF::OaiDcSerialization.new(work_show_presenter).to_oai_dc
  #      # => XML string
  #
  #    CHF::OaiDcSerialization.new(work_show_presenter).to_oai_dc(xml_decleration: true)
  #
  class OaiDcSerialization
    # all of em from https://drive.google.com/file/d/1fJEWhnYy5Ch7_ef_-V48-FAViA72OieG/view
    # why not, be complete in case we need em.
    NAMESPACES = {
      dpla: "http://dp.la/about/map/",
      cnt: "http://www.w3.org/2011/content#",
      dc: "http://purl.org/dc/elements/1.1/",
      dcterms: "http://purl.org/dc/terms/",
      dcmitype: "http://purl.org/dc/dcmitype/",
      edm: "http://www.europeana.eu/schemas/edm/",
      gn: "http://www.geonames.org/ontology#",
      getty: "http://vocab.getty.edu",
      oa: "http://www.w3.org/ns/oa#",
      ore: "http://www.openarchives.org/ore/terms/",
      rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
      rdfs: "http://www.w3.org/2000/01/rdf-schema#",
      skos: "http://www.w3.org/2004/02/skos/core#",
      svcs: "http://rdfs.org/sioc/services",
      wgs84: "http://www.w3.org/2003/01/geo/wgs84_pos#",
      oai_dc: "http://www.openarchives.org/OAI/2.0/oai_dc/"
    }

    # A "curation_concerns" style presenter, with `def initialize(solr_document, current_ability, request = nil)`
    class_attribute :presenter_class_name
    self.presenter_class_name = "CurationConcerns::GenericWorkShowPresenter"

    attr_reader :solr_document

    # @param solr_document [SolrDocument] represneting a GenericWork
    def initialize(solr_document)
      @solr_document = solr_document
    end

    def work_presenter
      @work_presenter ||= presenter_class_name.constantize.new(solr_document, Ability.new(nil))
    end

    # a string, which does not have an XML decleration or DTD
    def to_oai_dc(xml_decleration: false)
      save_options = if xml_decleration
        Nokogiri::XML::Node::SaveOptions::FORMAT
      else
        Nokogiri::XML::Node::SaveOptions::FORMAT + Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
      end
      as_oai_dc_builder.to_xml(save_with: save_options)
    end

    # A Nokogiri doc
    def as_oai_dc_builder
      builder = Nokogiri::XML::Builder.new do |xml|
        # have to use a hack for namespaced root element before we've provided the namespaces.
        xml.send("oai_dc:dc", xmlns_attribs) do
          xml["dc"].identifier in_our_app_url

          xml["dc"].title work_presenter.title.first

          xml["dc"].rights work_presenter.rights_url

          dc_creators.each do |creator|
            xml["dc"].creator creator
          end

          dc_contributors.each do |contributor|
            xml["dc"].contributor contributor
          end

          # Very unclear what minimal requirements for parseable date formats are.
          # We're just going to put our human-readable dates in a single dc:date, cause
          # PA Digital guidelines say they are not repeatable. We may have to do more
          # work later to give them something they can parse, even if we dumb our dates
          # down.
          display_dates = work_presenter.display_dates
          if display_dates.present?
            xml["dc"].date display_dates.join(", ")
          end

          xml["dc"].description work_presenter.plain_description

          # Mime types in DC:format
          work_presenter.content_types.each do |ctype|
            xml["dc"].format ctype
          end

          # PA Digital says language IS repeatable, and there's no need to actually give them
          # ISO 692-2, they'd just throw it out anyway.
          (work_presenter.language || []).each do |lang|
            xml["dc"].language lang
          end

          (work_presenter.publisher || []).each do |publisher|
            xml["dc"].publisher publisher
          end

          if work_presenter.rights_holder
            xml["dcterms"].rightsholder work_presenter.rights_holder.join(", ")
          end

          # Could do: dc:source archival location. A pain cause it requires collection, and
          # PA Digital says they don't currently pass it on to DPLA anyway, so we'll skip for now.
          # See CitableAttributes#archive_location for how we do it there.

          (work_presenter.subject || []).each do |subject|
            xml["dc"].subject subject
          end

          # PA Digital says dc:type IS repeatable.
          (work_presenter.resource_type || []).each do |type|
            xml["dc"].type type
          end
          # PA digital also says dc:type is the place to put any local vocab, so
          # we'll try our genres in there too.
          Array(work_presenter.genre_string).each do |genre|
            xml["dc"].type genre.downcase
          end


          # PA Digital wants the thumbnail in a repeated dc:identifier, okay then!
          xml["dc"].send(:"identifier", thumb_url)

          ########################
          #
          # PA Digital will probably throw these out and not forward them to DPLA, but they
          # are tags DPLA MAP asks for, we might as well include them so they are there in the future
          # if anyone wants em, without us having to code em then.

          xml["dpla"].originalRecord in_our_app_url
          xml["edm"].preview thumb_url
          xml["edm"].rights work_presenter.rights_url

          Array(work_presenter.genre_string).each do |genre|
            xml["edm"].hasType genre.downcase
          end

          # "The URL of a suitable source object in the best resolution available on the website of the Data
          # "Provider from which edm:preview could be generated for use in available portal."
          #
          # Sorry to go right to Rails routes, kind of poor encapsulation, but it's what we've got
          # for now.
          if work_presenter.representative_file_id
            xml["edm"].object routes.download_url(work_presenter.representative_file_set_id)
          end
        end
      end
    end

    protected

    def routes
      @routes ||= Class.new do
        # somewhere said this is a better way to use global routes to avoid memory leak in rails
        include Rails.application.routes.url_helpers
      end.new
    end

    def in_our_app_url
      "#{CHF::Env.lookup!(:app_url_base)}/works/#{work_presenter.id}"
    end

    def dc_creators
      # We'll use the same subset of all our 'maker' fields we use in our citations in CitableAttributes
      @dc_creators ||= begin
        arr =  work_presenter.creator_of_work || []
        arr += work_presenter.artist || []
        arr += work_presenter.author || []
        arr += work_presenter.engraver || []
        arr += work_presenter.manufacturer || []
        arr += work_presenter.photographer || []

        arr
      end
    end

    def dc_contributors
      arr =  work_presenter.addressee || []
      arr += work_presenter.after || []
      arr += work_presenter.contributor || []
      arr += work_presenter.interviewee || []
      arr += work_presenter.interviewer || []
      arr += work_presenter.manner_of || []
      arr += work_presenter.printer || []
      arr += work_presenter.printer_of_plates || []

      arr
    end

    # TODO add contributor


    # using our custom in-house object that can give us thumbnail URLs, but not with
    # quite a convenient API for this, oh well. We want "medium" _download_ size
    def thumb_url
      @thumb_url ||= begin
        service = ImageServiceHelper.image_url_service_class(CHF::Env.lookup(:image_server_downloads)).new(
          file_set_id: work_presenter.representative_file_set_id,
          file_id: work_presenter.representative_file_id,
          checksum: work_presenter.representative_checksum
        )
        download_options = service.download_options(no_content_disposition: true)
        url = (download_options.find { |h| h[:option_key] == "medium "} || download_options.first).try { |h| h[:url] }
        # make it an absolute url
        if url
          url = Addressable::URI.parse(CHF::Env.lookup!(:app_url_base)) + url
        end

        url
      end
    end

    def xmlns_attribs
      NAMESPACES.collect do |key, value|
        ["xmlns:#{key.to_s}", value]
      end.to_h
    end

  end
end
