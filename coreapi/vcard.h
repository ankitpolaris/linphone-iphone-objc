/*
vcard.h
Copyright (C) 2015  Belledonne Communications SARL

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

#ifndef LINPHONE_VCARD_H
#define LINPHONE_VCARD_H

#include <mediastreamer2/mscommon.h>

#ifndef LINPHONE_PUBLIC
#define LINPHONE_PUBLIC MS2_PUBLIC
#endif

#ifdef __cplusplus
extern "C"
{
#endif

/**
 * @addtogroup buddy_list
 * @{
 */

typedef struct _LinphoneVCard LinphoneVCard;

/**
 * Creates a LinphoneVCard object that has a pointer to an empty vCard
 */
LINPHONE_PUBLIC LinphoneVCard* linphone_vcard_new(void);

/**
 * Deletes a LinphoneVCard object properly
 * @param[in] vcard the LinphoneVCard to destroy
 */
LINPHONE_PUBLIC void linphone_vcard_free(LinphoneVCard *vcard);

/**
 * Uses belcard to parse the content of a file and returns all the vcards it contains as LinphoneVCards, or NULL if it contains none.
 * @param[in] file the path to the file to parse
 * @return \mslist{LinphoneVCard}
 */
LINPHONE_PUBLIC MSList* linphone_vcard_new_from_vcard4_file(const char *file);

/**
 * Returns the vCard4 representation of the LinphoneVCard.
 * @param[in] vcard the LinphoneVCard
 * @return a const char * that represents the vcard
 */
LINPHONE_PUBLIC const char* linphone_vcard_as_vcard4_string(LinphoneVCard *vcard);

/**
 * Sets the FN attribute of the vCard (which is mandatory).
 * @param[in] vcard the LinphoneVCard
 * @param[in] name the display name to set for the vCard
 */
LINPHONE_PUBLIC void linphone_vcard_set_full_name(LinphoneVCard *vcard, const char *name);

/**
 * Returns the FN attribute of the vCard, or NULL if it isn't set yet.
 * @param[in] vcard the LinphoneVCard
 * @return the display name of the vCard, or NULL
 */
LINPHONE_PUBLIC const char* linphone_vcard_get_full_name(const LinphoneVCard *vcard);

/**
 * Returns the list of SIP addresses (as const char *) in the vCard (all the IMPP attributes that has an URI value starting by "sip:") or NULL
 * @param[in] vcard the LinphoneVCard
 * @return \mslist{const char *}
 */
LINPHONE_PUBLIC MSList* linphone_vcard_get_sip_addresses(const LinphoneVCard *vcard);

/**
 * @}
 */

#ifdef __cplusplus
}
#endif

#endif