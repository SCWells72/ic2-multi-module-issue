@SuppressWarnings('PMD.ApexRecRestrictDatabaseUsage')
public with sharing class SObjectUtils {
	// =========================================================
	//  CONSTANTS
	// =========================================================

	private static final String TAG = SObjectUtils.class.getName();
	private static final Integer NAME_START_POSITION = 0;
	private static final Long FALLBACK_MILLIS_MULTIPLIER = 100; // 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 = 5500 ms if continued failure
	private static final Integer MAX_UPDATE_ATTEMPTS = 10;

	// =========================================================
	//  CONSTRUCTORS
	// =========================================================

	public SObjectUtils() {
		throw new UnsupportedOperationException('Can not instantiate a Util class');
	}

	// =========================================================
	//  PUBLIC STATIC METHODS
	// =========================================================

	public static void applySObjectValues(Map<String, Object> valuesMap, String keyStringPrefix, SObject record) {
		final Map<String, SObjectField> fieldsByName = record.getSObjectType().getDescribe().fields.getMap();
		final Map<String, Object> populatedValuesByField = record.getPopulatedFieldsAsMap();
		for (String fieldName : populatedValuesByField.keySet()) {
			final Object fieldValue = populatedValuesByField.get(fieldName);
			final SObjectField field = fieldsByName.get(fieldName);
			if (null != field) {
				final String localFieldName = field.getDescribe().getLocalName();
				valuesMap.put(keyStringPrefix + '.' + localFieldName, fieldValue);
			}
		}
	}

	public static Type getType(SObject obj) {
		if (obj == null)
			return null;
		return Type.forName(obj.getSObjectType().getDescribe().getName());
	}

	public static void applyValuesByField(SObject target, Map<String, Object> valuesByField) {
		final String targetTypeName = target.getSObjectType().getDescribe().getName();
		final Map<String, String> attributeMap = new Map<String, String>{ 'type' => targetTypeName };
		final Map<String, Object> typedValueMap = valuesByField.clone(); // Clone the map so we don't mutate caller's map
		typedValueMap.put('attributes', attributeMap);

		final String jsonData = JSON.serialize(typedValueMap);
		final SObject withConvertedValues = (SObject) JSON.deserialize(jsonData, Type.forName(null, targetTypeName));

		final Map<String, SObjectField> fieldsByName = target.getSObjectType().getDescribe().fields.getMap();
		for (String fieldName : valuesByField.keySet()) {
			final SObjectField currentField = fieldsByName.get(fieldName);
			//Do not set currentField value when the field is calculated (Formula)
			if (currentField != null && !currentField.getDescribe().isCalculated()) {
				final Object convertedValue = withConvertedValues.get(currentField);
				target.put(currentField, convertedValue);
			}
		}
	}

	public static void copyFieldValues(
		SObject source,
		SObject destination,
		Map<String, SObjectField> sourceToDestinationMapping
	) {
		for (String sourceField : sourceToDestinationMapping.keySet()) {
			destination.put(sourceToDestinationMapping.get(sourceField), getFieldValue(source, sourceField));
		}
	}

	public static Object getFieldValue(SObject obj, String field) {
		List<String> fields = field.split('\\.');
		Integer numFields = fields.size() - 1;
		for (Integer i = 0; i < numFields; i++) {
			if (obj == null) {
				break;
			}
			obj = obj.getSObject(fields[i]);
		}

		if (obj == null) {
			return null;
		}

		return obj.get(fields[numFields]);
	}

	public static Boolean isIdOfType(Id sObjectId, SObjectType sObjectType) {
		return sObjectId != null && sObjectId.getSobjectType() == sObjectType;
	}

	public static Boolean isId(String stringId) {
		return stringId instanceof Id;
	}

	public static void attemptContentiousUpdate(SObject toUpdate, Boolean throwExceptionIfFail) {
		Integer attempts = 0;
		while (attempts < MAX_UPDATE_ATTEMPTS) {
			try {
				// @SecurityException SE1 - only called from asynchronous billing batch job contexts
				update toUpdate;
				break;
			} catch (DmlException ex) {
				attempts++;
				if (attempts >= MAX_UPDATE_ATTEMPTS) {
					if (throwExceptionIfFail) {
						throw ex;
					} else {
						break;
					}
				}
				Long breakSpinLock = System.currentTimeMillis() + (attempts * FALLBACK_MILLIS_MULTIPLIER);
				while (System.currentTimeMillis() < breakSpinLock) {
					// SPIN
				}
			}
		}
	}

	public static String truncateString(String value, Integer characterLength) {
		String newName = value;
		Integer maxLength = (characterLength >= 1) ? characterLength : 1; //No allowing values below 1

		if (value.length() > maxLength) {
			newName = value.substring(NAME_START_POSITION, maxLength - 1);
		}

		return newName;
	}

	public static Boolean isFieldValid(SObjectType sType, String field) {
		try {
			sType.newSObject().get(field);
			return true;
		} catch (System.SObjectException e) {
			return false;
		}
	}
}
