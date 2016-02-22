# set up local config values, and overwrite any in sufia that we changed.
# WARNING: changes may necessitate data migration!!
Sufia.config do |config|

  config.minter_statefile = Rails.env.production? ? '/var/sufia/minter-state' : '/tmp/minter-state'

  # Contact form
  config.from_email = 'no-reply@chemheritage.org'

  # model configuration
  config.makers = {
    artist:       ::RDF::Vocab::MARCRelators.art,
    author:       ::RDF::Vocab::MARCRelators.aut,
    creator_of_work:      ::RDF::Vocab::DC11.creator,
    contributor:  ::RDF::Vocab::DC11.contributor,
    interviewee:  ::RDF::Vocab::MARCRelators.ive,
    interviewer:  ::RDF::Vocab::MARCRelators.ivr,
    manufacturer: ::RDF::Vocab::MARCRelators.mfr,
    photographer: ::RDF::Vocab::MARCRelators.pht,
    publisher:    ::RDF::Vocab::DC11.publisher,
  }

  config.places = {
    place_of_interview: ::RDF::Vocab::MARCRelators.evp,
    place_of_manufacture: ::RDF::Vocab::MARCRelators.mfp,
    place_of_publication: ::RDF::Vocab::MARCRelators.pup,
    place_of_creation: ::RDF::Vocab::MARCRelators.prp,
  }

  # form field configuration
  config.credit_names = [
    'Douglas Lockard',
    'Gregory Tobias',
    'Mark Backrath',
    'Penn School of Medicine',
    'Will Brown',
  ]

  config.credit_roles = {
    'photographer' => 'Photographed by',
  }

  config.cc_licenses = {
    'In Copyright' => 'http://rightsstatements.org/vocab/InC/1.0/',
    'In Copyright - EU Orphan Work' => 'http://rightsstatements.org/vocab/InC­OW­EU/1.0/',
    'In Copyright - Rights­holder(s) Unlocatable or Unidentifiable' => 'http://rightsstatements.org/vocab/InC­RUU/1.0/',
    'In Copyright - Educational Use Permitted' => 'http://rightsstatements.org/vocab/InC­EDU/1.0/',
    'In Copyright - Non­Commercial Use Permitted' => 'http://rightsstatements.org/vocab/InC­NC/1.0/',
    'Out Of Copyright - Non­Commercial Use Only' => 'http://rightsstatements.org/vocab/OOC­NC/1.0/',
    'No Copyright - Contractual Restrictions' => 'http://rightsstatements.org/vocab/NoC­CR/1.0/',
    'No Copyright - Other Known Legal Restrictions' => 'http://rightsstatements.org/vocab/NoC­OKLR/1.0/',
    'No Copyright -  United States' => 'http://rightsstatements.org/vocab/NoC-US/1.0/',
    'No Known Copyright' => 'http://rightsstatements.org/vocab/NKC/1.0/',
    'Public Domain Mark 1.0' => 'http://creativecommons.org/publicdomain/mark/1.0/',
  }

  config.cc_licenses_reverse = Hash[*config.cc_licenses.to_a.flatten.reverse]

  config.divisions = [
    'Archives',
    'Center for Oral History',
    'Museum',
    'Othmer Library of Chemical History',
  ]

  config.file_creators = [
    'Brown, Will',
    'DiMeo, Michelle',
    'George Blood Audio LP',
    'Kativa, Hillary',
    'Lockard, Douglas',
    'Lu, Cathleen',
    'Miller, Megan',
    'Newhouse, Sarah',
    'The University of Pennsylvania Libraries',
    'Tobias, Gregory',
    'Voelkel, James',
  ]

  config.external_ids_hash = {
    'object' => 'Object ID',
    'bib' => 'Sierra Bib. No.',
    'item' => 'Sierra Item No.',
    'accn' => 'Accession No.',
    'aspace' => 'ASpace Reference No.',
    'interview' => 'Oral History Interview No.',
  }

  config.genres = [
    'Advertisements',
    'Artifacts',
    'Business correspondence',
    'Chemistry sets',
    'Engravings',
    'Etchings',
    'Handbooks and manuals',
    'Manuscripts',
    'Minutes (Records)',
    'Oral histories',
    'Paintings',
    'Pamphlets',
    'Personal correspondence',
    'Photographs',
    'Plastics',
    'Portraits',
    'Prints',
    'Rare books',
    'Records (Documents)',
    'Scientific apparatus and instruments',
    'Slides',
    'Stereographs',
  ]

  config.physical_container_fields = {
    'b'=>'box', 'f'=>'folder', 'v'=>'volume', 'p'=>'part'
  }

  config.resource_types = {
    "Image" => "Image",
    "Moving Image" => "Moving Image",
    "Physical Object" => "Physical Object",
    "Sound" => "Sound",
    "Text" => "Text"
  }

  config.resource_types_to_schema = {
    "Moving Image" => "http://purl.org/dc/dcmitype/MovingImage",
    "Image" => "http://purl.org/dc/dcmitype/StillImage",
    "Physical Object" => "http://purl.org/dc/dcmitype/PhysicalObject",
    "Sound" => "http://purl.org/dc/dcmitype/Sound",
    "Text" => "http://purl.org/dc/dcmitype/Text"
  }

end
