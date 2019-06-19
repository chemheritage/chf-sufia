class BatchEditForm < Sufia::Forms::BatchEditForm
  require_dependency Rails.root.join('lib','chf','utils','parse_fields')

  CHF::Utils::ParseFields.external_ids_hash.keys.each do |k|
    attr_accessor "#{k}_external_id".to_s
  end

  self.terms = [
    :division,
    # This one doesn't quite work.
    # :physical_container,
    :rights_holder,
    :provenance,
    :file_creator,
    :additional_title,
    :identifier,
    :admin_note,
    # Nested attributes don't work
    #:date_of_work,
    #:inscription,
    #:additional_credit,
    :resource_type,
    :subject, :language,
    :related_url,
    :after,
    :artist,
    :attributed_to,
    :author,
    :addressee,
    :creator_of_work,
    :contributor,
    :editor,
    :engraver,
    :interviewee,
    :interviewer,
    :manner_of,
    :manufacturer,
    :photographer,
    :printer,
    :printer_of_plates,
    :publisher,
    :place_of_interview,
    :place_of_manufacture,
    :place_of_publication,
    :place_of_creation,
    :exhibition,
    :project,
    :source,
    :school_of,
    :genre_string,
    :medium,
    :extent,
    :series_arrangement,
    :rights
  ]

  self.required_fields = []

  def self.model_attributes(params)
    # The model expects the "Copyright status" field
    # to be multi-value, so turn it into an array
    # before invoking super.
    params[:rights] = Array(params[:rights]) if params[:rights].present?
    clean_params = super # hydra-editor/app/forms/hydra_editor/form.rb:54
    clean_params = encode_external_id(params, clean_params)
    clean_params.keys.each do |key|
      # strip ALL the things!
      if clean_params[key].is_a?(Array)
        clean_params[key].map!(&:strip)
      elsif clean_params[key].is_a?(String)
        clean_params[key] = clean_params[key].strip
      end
    end
    # Permission attributes are getting stripped indiscriminately
    # due to a bug released in sufia 7.3:
    # https://github.com/projecthydra-labs/hyrax/issues/652
    clean_params['permissions_attributes'] = params['permissions_attributes'] if params['permissions_attributes']
    clean_params
  end

  private

    # It's a multi-value field
    def self.encode_external_id(params, clean_params)
    #unless params['identifier'].nil?
      result = []
      CHF::Utils::ParseFields.external_ids_hash.keys.each do |k|
        param = "#{k}_external_id"
        if params[param].present?
          params[param].each do |id_value|
            result << "#{k}-#{id_value}" unless id_value.empty?
          end
        end
      end
      unless result.empty?
        clean_params['identifier'] = result
      end
      clean_params
    end

    # If this property of the model is an array (which is the default) then return true.
    # If it accepts only one value, return false.
    # Note that this value is stored as a boolean in the properties of the model class.
    def accepts_multiple_values?(prop)
      model_class.properties[prop.to_s].instance_values['opts'][:multiple]
    end


    # This overrides the superclass,
    # https://github.com/samvera/sufia/blob/v7.4.0/app/forms/sufia/forms/batch_edit_form.rb
    # The goal here is to allow single-value fields to be edited via the form.
    # To determine whether a field expects a single value or an array, we check the model's properties.
    # If the field accepts an array, we process it as in the superclass. If it accepts a single value,
    # then we process it slightly differently, storing the values in plain_attributes
    # instead of combined_attributes.
    def initialize_combined_fields
      plain_attributes = {}
      combined_attributes = {}
      permissions = []
      # For each of the files in the batch, set the attributes to be the concatenation of all the attributes
      batch_document_ids.each do |doc_id|
        work = model_class.find(doc_id)
        terms.each do |key|
          if accepts_multiple_values?(key)
            combined_attributes[key] ||= []
            combined_attributes[key] = (combined_attributes[key] +  work[key].to_a).uniq
          else
            plain_attributes[key] = work[key]
          end
        end
        names << work.to_s
        permissions = (permissions + work.permissions).uniq
      end

      terms.each do |key|
        if accepts_multiple_values?(key)
          # if value is empty, we create an one element array to loop over for output
          model[key] = combined_attributes[key].empty? ? [''] : combined_attributes[key]
        else
          model[key] = plain_attributes[key]
        end
      end
      model.permissions_attributes = [{ type: 'group', name: 'public', access: 'read' }]
      # override sufia form's visibility default if we can find a better option
      model.visibility = set_batch_visibility
    end

    # Return a value for visibility only if all the items in the batch have the same value.
    def set_batch_visibility
      range = batch_document_ids.map{ |doc_id| model_class.find(doc_id).visibility }.uniq
      return nil if range.count > 1
      range.first
    end
end
